import { Inject, Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Job } from 'bullmq';
import type { z } from 'zod';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { addMinutes, cameroonDate } from '../common/time.js';
import { type OrderChange, OrderEventsBus } from '../events/order-events.bus.js';
import type { DispatchOffer, Order, Prisma } from '../generated/prisma/client.js';
import type { DispatchOfferOutcome } from '../generated/prisma/enums.js';
import { NotificationService } from '../notifications/notification.service.js';
import { OrderTransitionsService } from '../orders/order-transitions.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { QueueService } from '../redis/queue.service.js';
import { uncoveredDocuments } from '../riders/riders.service.js';
import type { CandidateDto, OfferDto } from './dispatch.schemas.js';
import { PresenceService } from './presence.service.js';
import {
  cashCarried,
  type Ineligibility,
  ineligibilities,
  offersForRound,
  type RiderSnapshot,
  score,
} from './rider-scoring.js';

/** Courses en cours pour un livreur (il a le colis ou doit aller le chercher). */
export const ACTIVE_RIDER_STATUSES = [
  'ASSIGNED',
  'PICKED_UP',
  'IN_DELIVERY',
  'DELIVERY_FAILED',
] as const;

/** Délai de grâce après l'échéance d'une offre : le réseau mobile peut retarder la réponse. */
const ACCEPT_GRACE_MS = 3_000;
/** Une commande programmée part en recherche de livreur ce délai avant son créneau. */
export const SCHEDULED_LEAD_MINUTES = 20;
/** Livreurs examinés autour du point d'enlèvement à chaque rayon. */
const NEARBY_LIMIT = 30;

type OrderWithPlaces = Prisma.OrderGetPayload<{
  include: {
    pickupAddress: { include: { neighborhood: true } };
    dropoffAddress: { include: { neighborhood: true } };
  };
}>;

interface Candidate extends RiderSnapshot {
  userId: string;
  score: number;
}

type RoundResult =
  | { kind: 'inactive' }
  | { kind: 'waiting'; nextExpiry: Date; closed: DispatchOffer[]; order: Order }
  | { kind: 'none'; closed: DispatchOffer[]; order: Order }
  | {
      kind: 'offered';
      closed: DispatchOffer[];
      order: OrderWithPlaces;
      offers: { offer: DispatchOffer; userId: string }[];
    };

/** Une commande commandée, payée d'avance ou réglée à la livraison, peut partir. */
function readyForDispatch(order: Pick<Order, 'feePayer' | 'feePaymentMethod'>): boolean {
  return order.feePayer === 'RECIPIENT' || order.feePaymentMethod === 'CASH';
}

/**
 * Attribution automatique des courses (D1, D2, D4) et manuelle (D3).
 *
 * Une recherche se fait par tours. Aux premiers tours (DISPATCH_SINGLE_OFFER_ROUNDS), la
 * course est proposée au livreur le mieux placé, qui a DISPATCH_OFFER_TIMEOUT_SECONDS pour
 * répondre ; après ces refus ou silences, elle est diffusée à DISPATCH_BROADCAST_SIZE
 * livreurs à la fois, le premier qui accepte l'emporte. Le rayon de recherche s'élargit
 * tant que personne n'est disponible, avec une nouvelle tentative régulière. Après
 * DISPATCH_ALERT_AFTER_SECONDS sans livreur, l'équipe des opérations est alertée.
 *
 * Chaque tour s'exécute sous un verrou PostgreSQL propre à la commande : plusieurs instances
 * de l'API, l'expiration d'une offre et la réponse d'un livreur ne se marchent pas dessus.
 * Les tâches différées (expiration, nouvelle tentative) passent par la file ; un balayage
 * périodique rattrape tout ce qu'une panne aurait laissé en suspens.
 */
@Injectable()
export class DispatchService implements OnModuleInit {
  private readonly logger = new Logger(DispatchService.name);
  private readonly radii: number[];

  constructor(
    private readonly prisma: PrismaService,
    private readonly presence: PresenceService,
    private readonly realtime: RealtimeService,
    private readonly notifications: NotificationService,
    private readonly queue: QueueService,
    private readonly bus: OrderEventsBus,
    private readonly transitions: OrderTransitionsService,
    @Inject(ENV) private readonly env: Env,
  ) {
    this.radii = env.DISPATCH_RADII_METERS.split(',').map(Number);
  }

  onModuleInit(): void {
    this.bus.subscribe('dispatch', (change) => this.onOrderChange(change));
    this.queue.register('dispatch', (job: Job<{ orderId: string }>) =>
      this.runRound(job.data.orderId).then(() => undefined),
    );
  }

  private async onOrderChange(change: OrderChange): Promise<void> {
    if (change.to === 'SEARCHING_RIDER') {
      await this.runRound(change.order.id);
    } else if (change.from === 'SEARCHING_RIDER') {
      // Attribution manuelle ou annulation pendant la recherche : les offres sont retirées.
      await this.closePendingOffers(change.order.id, 'WITHDRAWN');
    }
  }

  // --- Tours de proposition -----------------------------------------------------------------

  /**
   * Fait avancer la recherche d'une commande : clôt les offres échues, puis propose la
   * course au tour suivant s'il n'y a plus d'offre en attente. Sans effet si la commande
   * n'est plus en recherche. Peut être rappelée à tout moment (idempotente).
   */
  async runRound(orderId: string, now = new Date()): Promise<RoundResult['kind']> {
    const result = await this.prisma.$transaction(async (tx) => {
      await lockOrder(tx, orderId);
      const order = await tx.order.findUnique({
        where: { id: orderId },
        include: {
          pickupAddress: { include: { neighborhood: true } },
          dropoffAddress: { include: { neighborhood: true } },
        },
      });
      if (order?.status !== 'SEARCHING_RIDER') return { kind: 'inactive' } as const;

      const closed = await tx.dispatchOffer.updateManyAndReturn({
        where: { orderId, outcome: 'PENDING', expiresAt: { lte: now } },
        data: { outcome: 'EXPIRED' },
      });
      const pending = await tx.dispatchOffer.findFirst({
        where: { orderId, outcome: 'PENDING' },
        orderBy: { expiresAt: 'asc' },
      });
      if (pending) return { kind: 'waiting', nextExpiry: pending.expiresAt, closed, order } as const;

      const history = await tx.dispatchOffer.findMany({
        where: { orderId },
        select: { riderId: true, outcome: true, round: true, offeredAt: true },
      });
      const since = order.searchingSince ?? order.updatedAt;
      const thisSearch = history.filter((offer) => offer.offeredAt >= since);
      // Un livreur qui a refusé ou rendu la course ne la revoit pas ; un silence, si
      // personne d'autre n'est disponible.
      const excluded = new Set(
        history
          .filter((offer) => offer.outcome === 'DECLINED' || offer.outcome === 'ACCEPTED')
          .map((offer) => offer.riderId),
      );
      for (const riderId of await releasedBy(tx, orderId)) excluded.add(riderId);
      const silent = new Set(
        thisSearch.filter((offer) => offer.outcome === 'EXPIRED').map((offer) => offer.riderId),
      );
      const searchRound = new Set(thisSearch.map((offer) => offer.round)).size + 1;
      const round = Math.max(0, ...history.map((offer) => offer.round)) + 1;
      const size = offersForRound(
        searchRound,
        this.env.DISPATCH_SINGLE_OFFER_ROUNDS,
        this.env.DISPATCH_BROADCAST_SIZE,
      );

      const candidates = await this.findCandidates(tx, order, excluded, silent, size);
      if (candidates.length === 0) return { kind: 'none', closed, order } as const;

      const expiresAt = new Date(now.getTime() + this.env.DISPATCH_OFFER_TIMEOUT_SECONDS * 1000);
      // Un livreur qui vient de recevoir une autre offre est ignoré (une offre à la fois).
      const offers = await tx.dispatchOffer.createManyAndReturn({
        data: candidates.map((candidate) => ({
          orderId,
          riderId: candidate.riderId,
          round,
          approachMeters: candidate.distanceMeters,
          offeredAt: now,
          expiresAt,
        })),
        skipDuplicates: true,
      });
      if (offers.length === 0) return { kind: 'none', closed, order } as const;
      const userOf = new Map(candidates.map((candidate) => [candidate.riderId, candidate.userId]));
      return {
        kind: 'offered',
        closed,
        order,
        offers: offers.map((offer) => ({ offer, userId: userOf.get(offer.riderId) ?? '' })),
      } as const;
    });

    if (result.kind === 'inactive') return result.kind;
    await this.announceClosed(result.closed);
    switch (result.kind) {
      case 'waiting':
        // Expiration lancée trop tôt (horloges) : on reviendra à l'échéance.
        await this.schedule(result.order.id, result.nextExpiry.getTime() - now.getTime(), 'expiry');
        break;
      case 'none':
        await this.schedule(result.order.id, this.env.DISPATCH_RETRY_SECONDS * 1000, 'retry');
        break;
      case 'offered':
        await this.schedule(
          result.order.id,
          this.env.DISPATCH_OFFER_TIMEOUT_SECONDS * 1000,
          'expiry',
        );
        await Promise.all(
          result.offers.map(({ offer, userId }) => this.announceOffer(result.order, offer, userId)),
        );
        break;
    }
    await this.alertIfLate(result.order, now);
    return result.kind;
  }

  private async findCandidates(
    tx: Prisma.TransactionClient,
    order: OrderWithPlaces,
    excluded: Set<string>,
    silent: Set<string>,
    size: number,
  ): Promise<Candidate[]> {
    const orderCash = cashCarried(order);
    const seen = new Set<string>();
    let eligible: Candidate[] = [];
    for (const radius of this.radii) {
      const nearby = await this.presence.nearby(
        order.pickupAddress.latitude,
        order.pickupAddress.longitude,
        radius,
        NEARBY_LIMIT,
      );
      const fresh = nearby.filter(
        (rider) => !excluded.has(rider.riderId) && !seen.has(rider.riderId),
      );
      fresh.forEach((rider) => seen.add(rider.riderId));
      const snapshots = await this.snapshots(tx, fresh);
      eligible = eligible.concat(
        snapshots.filter((rider) => ineligibilities(rider, orderCash).length === 0),
      );
      const preferred = eligible.filter((rider) => !silent.has(rider.riderId));
      if (preferred.length >= size) break;
    }
    const preferred = eligible.filter((rider) => !silent.has(rider.riderId));
    const pool = preferred.length > 0 ? preferred : eligible;
    return pool.sort((a, b) => a.score - b.score).slice(0, size);
  }

  /** État de chaque livreur proche, lu en une fois (pièces, courses, offres, espèces). */
  private async snapshots(
    tx: Prisma.TransactionClient,
    nearby: { riderId: string; distanceMeters: number }[],
  ): Promise<Candidate[]> {
    if (nearby.length === 0) return [];
    const ids = nearby.map((rider) => rider.riderId);
    const riders = await tx.riderProfile.findMany({
      where: { id: { in: ids }, status: 'ACTIVE', user: { status: 'ACTIVE' } },
      include: {
        documents: true,
        orders: { where: { status: { in: [...ACTIVE_RIDER_STATUSES] } }, select: { id: true } },
        offers: { where: { outcome: 'PENDING' }, select: { id: true } },
      },
    });
    const cash = await this.cashHeld(tx, ids);
    const distance = new Map(nearby.map((rider) => [rider.riderId, rider.distanceMeters]));
    const today = cameroonDate(new Date());
    return riders.map((rider) => {
      const snapshot: RiderSnapshot = {
        riderId: rider.id,
        distanceMeters: distance.get(rider.id) ?? 0,
        activeOrders: rider.orders.length,
        hasPendingOffer: rider.offers.length > 0,
        documentsValid: uncoveredDocuments(rider.documents, ['APPROVED'], today).length === 0,
        cashHeld: cash.get(rider.id) ?? 0,
        cashLimit: rider.cashLimit,
        ratingSum: rider.ratingSum,
        ratingCount: rider.ratingCount,
      };
      return { ...snapshot, userId: rider.userId, score: score(snapshot) };
    });
  }

  /**
   * Espèces détenues par chaque livreur (D4, G5). En attendant le grand livre de la
   * phase 3, ce sont les encaissements en espèces enregistrés ; la phase 3 y retranchera
   * les dépôts et lira le solde du compte « espèces détenues ».
   */
  private async cashHeld(tx: Prisma.TransactionClient, riderIds: string[]): Promise<Map<string, number>> {
    const rows = await tx.codCollection.groupBy({
      by: ['riderId'],
      where: { riderId: { in: riderIds }, method: 'CASH' },
      _sum: { collectedAmount: true },
    });
    return new Map(rows.map((row) => [row.riderId, row._sum.collectedAmount ?? 0]));
  }

  private async schedule(orderId: string, delayMs: number, kind: 'expiry' | 'retry'): Promise<void> {
    if (!this.queue.workersEnabled) return; // Tests : le balayage fait avancer les tours.
    const at = Date.now() + Math.max(0, delayMs);
    await this.queue.add(
      'dispatch',
      kind,
      { orderId },
      {
        delay: Math.max(0, delayMs),
        // Une seule tâche par commande et par échéance, même si plusieurs instances planifient.
        jobId: `${kind}-${orderId}-${Math.ceil(at / 100)}`,
        attempts: 3,
        backoff: { type: 'fixed', delay: 1_000 },
      },
    );
  }

  // --- Réponses du livreur ------------------------------------------------------------------

  async pendingOffersFor(userId: string): Promise<z.output<typeof OfferDto>[]> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    const offers = await this.prisma.dispatchOffer.findMany({
      where: { riderId: rider.id, outcome: 'PENDING', expiresAt: { gt: new Date() } },
      include: {
        order: {
          include: {
            pickupAddress: { include: { neighborhood: true } },
            dropoffAddress: { include: { neighborhood: true } },
          },
        },
      },
      orderBy: { offeredAt: 'asc' },
    });
    return offers.map((offer) => toOfferDto(offer.order, offer));
  }

  /** Le livreur accepte : la course lui est attribuée si l'offre tient toujours. */
  async accept(offerId: string, userId: string, now = new Date()): Promise<Order> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    const { change, withdrawn } = await this.prisma.$transaction(async (tx) => {
      const found = await tx.dispatchOffer.findUnique({ where: { id: offerId } });
      if (found?.riderId !== rider.id) throw AppError.notFound('OFFER_NOT_FOUND');
      await lockOrder(tx, found.orderId);
      const offer = await tx.dispatchOffer.findUniqueOrThrow({ where: { id: offerId } });
      if (offer.outcome !== 'PENDING') throw AppError.conflict('OFFER_NO_LONGER_AVAILABLE');
      if (offer.expiresAt.getTime() + ACCEPT_GRACE_MS < now.getTime()) {
        throw AppError.conflict('OFFER_EXPIRED');
      }
      if (rider.status !== 'ACTIVE') throw AppError.forbidden('RIDER_NOT_ACTIVE');
      const order = await tx.order.findUniqueOrThrow({ where: { id: offer.orderId } });
      if (order.status !== 'SEARCHING_RIDER') throw AppError.conflict('OFFER_NO_LONGER_AVAILABLE');

      await tx.dispatchOffer.update({
        where: { id: offer.id },
        data: { outcome: 'ACCEPTED', respondedAt: now },
      });
      const withdrawn = await tx.dispatchOffer.updateManyAndReturn({
        where: { orderId: order.id, outcome: 'PENDING' },
        data: { outcome: 'WITHDRAWN', respondedAt: now },
      });
      const { change } = await this.transitions.applyIn(
        tx,
        order,
        'ASSIGNED',
        { id: userId, role: 'RIDER' },
        { riderId: rider.id, note: 'Proposition acceptée' },
      );
      return { change, withdrawn };
    });
    await this.announceClosed(withdrawn);
    await this.bus.publish(change);
    return change.order;
  }

  /** Le livreur refuse : la course part aussitôt au suivant s'il n'y a plus d'offre en cours. */
  async decline(offerId: string, userId: string, now = new Date()): Promise<void> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    const orderId = await this.prisma.$transaction(async (tx) => {
      const found = await tx.dispatchOffer.findUnique({ where: { id: offerId } });
      if (found?.riderId !== rider.id) throw AppError.notFound('OFFER_NOT_FOUND');
      await lockOrder(tx, found.orderId);
      const { count } = await tx.dispatchOffer.updateMany({
        where: { id: offerId, outcome: 'PENDING' },
        data: { outcome: 'DECLINED', respondedAt: now },
      });
      return count === 1 ? found.orderId : null;
    });
    if (orderId) await this.runRound(orderId, now);
  }

  /** Le livreur passe hors ligne : ses offres en attente sont refusées. */
  async declineAllFor(riderId: string, now = new Date()): Promise<void> {
    const pending = await this.prisma.dispatchOffer.findMany({
      where: { riderId, outcome: 'PENDING' },
      include: { rider: { select: { userId: true } } },
    });
    for (const offer of pending) await this.decline(offer.id, offer.rider.userId, now);
  }

  private async closePendingOffers(orderId: string, outcome: DispatchOfferOutcome): Promise<void> {
    const closed = await this.prisma.dispatchOffer.updateManyAndReturn({
      where: { orderId, outcome: 'PENDING' },
      data: { outcome, respondedAt: new Date() },
    });
    await this.announceClosed(closed);
  }

  // --- Attribution manuelle (D3) --------------------------------------------------------------

  /**
   * Le dispatcheur confie la course à un livreur, y compris pour la retirer à un autre
   * (réattribution). Les deux changements de statut sont tracés dans l'historique.
   */
  async assignManually(
    orderId: string,
    riderId: string,
    actorId: string,
    note: string | undefined,
  ): Promise<{ order: Order; previousRiderUserId: string | null }> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { id: riderId } });
    if (rider?.status !== 'ACTIVE') throw AppError.unprocessable('RIDER_NOT_FOUND');
    const actor = { id: actorId, role: 'DISPATCHER' as const };
    const { changes, withdrawn, previousRiderUserId } = await this.prisma.$transaction(
      async (tx) => {
        await lockOrder(tx, orderId);
        let order = await tx.order.findUnique({
          where: { id: orderId },
          include: { rider: { select: { userId: true } } },
        });
        if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
        if (order.riderId === riderId) throw AppError.conflict('ORDER_ALREADY_ASSIGNED_TO_RIDER');
        const changes: OrderChange[] = [];
        const previousRiderUserId = order.rider?.userId ?? null;
        if (order.status === 'ASSIGNED') {
          const released = await this.transitions.applyIn(tx, order, 'SEARCHING_RIDER', actor, {
            note: note ?? 'Réattribution par le dispatch',
          });
          changes.push(released.change);
          order = { ...released.order, rider: null };
        }
        const withdrawn = await tx.dispatchOffer.updateManyAndReturn({
          where: { orderId, outcome: 'PENDING' },
          data: { outcome: 'WITHDRAWN', respondedAt: new Date() },
        });
        const assigned = await this.transitions.applyIn(tx, order, 'ASSIGNED', actor, {
          riderId,
          note,
        });
        changes.push(assigned.change);
        return { changes, withdrawn, previousRiderUserId };
      },
    );
    await this.announceClosed(withdrawn);
    // Seul le dernier changement compte pour les abonnés : l'attribution.
    const last = changes.at(-1) as OrderChange;
    await this.bus.publish(last);
    if (previousRiderUserId) {
      this.realtime.toUser(previousRiderUserId, 'order.status', {
        orderId,
        reference: last.order.reference,
        status: 'REASSIGNED',
        at: new Date().toISOString(),
      });
      await this.notifications.toUser(previousRiderUserId, {
        template: 'RIDER_ORDER_REASSIGNED',
        params: { reference: last.order.reference },
        data: { type: 'order.reassigned', orderId },
        orderId,
      });
    }
    return { order: last.order, previousRiderUserId };
  }

  /** Livreurs proches du point d'enlèvement, éligibles ou non, pour le dispatcheur (D3). */
  async candidatesFor(orderId: string): Promise<z.output<typeof CandidateDto>[]> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { pickupAddress: true },
    });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    const maxRadius = Math.max(...this.radii);
    const nearby = await this.presence.nearby(
      order.pickupAddress.latitude,
      order.pickupAddress.longitude,
      maxRadius,
      50,
    );
    const snapshots = await this.snapshots(this.prisma, nearby);
    const riders = await this.prisma.riderProfile.findMany({
      where: { id: { in: snapshots.map((s) => s.riderId) } },
      include: { user: { select: { fullName: true, phone: true } } },
    });
    const byId = new Map(riders.map((rider) => [rider.id, rider]));
    const positions = await this.presence.positions(snapshots.map((s) => s.riderId));
    const orderCash = cashCarried(order);
    return snapshots
      .sort((a, b) => a.score - b.score)
      .map((snapshot) => {
        const rider = byId.get(snapshot.riderId);
        const position = positions.get(snapshot.riderId);
        const reasons: Ineligibility[] = ineligibilities(snapshot, orderCash);
        return {
          riderId: snapshot.riderId,
          name: rider?.user.fullName ?? null,
          phone: rider?.user.phone ?? '',
          vehicleType: rider?.vehicleType ?? 'MOTORBIKE',
          distanceMeters: snapshot.distanceMeters,
          score: snapshot.score,
          activeOrders: snapshot.activeOrders,
          rating: snapshot.ratingCount > 0 ? snapshot.ratingSum / snapshot.ratingCount : null,
          ineligibleBecause: reasons,
          position: position
            ? {
                latitude: position.latitude,
                longitude: position.longitude,
                at: position.at.toISOString(),
              }
            : null,
        };
      });
  }

  // --- Balayage et alertes ------------------------------------------------------------------

  @Cron('*/15 * * * * *', { name: 'dispatch-sweep' })
  async scheduledSweep(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.sweep();
  }

  /**
   * Rattrapage périodique : commandes programmées arrivées à leur créneau, recherches
   * sans offre en cours (panne, file indisponible), offres échues, alertes au dispatch.
   */
  async sweep(now = new Date()): Promise<{ started: number; advanced: number }> {
    await this.presence.purgeStale();

    const due = await this.prisma.order.findMany({
      where: { status: 'CREATED', scheduledFor: { lte: addMinutes(now, SCHEDULED_LEAD_MINUTES) } },
      take: 200,
    });
    let started = 0;
    for (const order of due.filter(readyForDispatch)) {
      try {
        await this.transitions.apply(order.id, 'SEARCHING_RIDER', { id: null, role: 'SYSTEM' });
        started += 1;
      } catch (error) {
        if (!(error instanceof AppError)) throw error; // Déjà lancée par une autre instance.
      }
    }

    const searching = await this.prisma.order.findMany({
      where: {
        status: 'SEARCHING_RIDER',
        offers: { none: { outcome: 'PENDING', expiresAt: { gt: now } } },
      },
      select: { id: true },
      orderBy: { searchingSince: 'asc' },
      take: 500,
    });
    for (const { id } of searching) {
      try {
        await this.runRound(id, now);
      } catch (error) {
        this.logger.error(`Tour d'attribution en échec (${id})`, error);
      }
    }
    return { started, advanced: searching.length };
  }

  /** Alerte unique au dispatch quand une course attend un livreur depuis trop longtemps (D2). */
  private async alertIfLate(order: Order, now: Date): Promise<void> {
    if (!order.searchingSince) return;
    const waitedMs = now.getTime() - order.searchingSince.getTime();
    if (waitedMs < this.env.DISPATCH_ALERT_AFTER_SECONDS * 1000) return;
    const { count } = await this.prisma.order.updateMany({
      where: { id: order.id, status: 'SEARCHING_RIDER', dispatchAlertedAt: null },
      data: { dispatchAlertedAt: now },
    });
    if (count !== 1) return;
    const minutes = Math.floor(waitedMs / 60_000);
    this.realtime.toOps('ops.dispatch-alert', {
      orderId: order.id,
      reference: order.reference,
      searchingSince: order.searchingSince.toISOString(),
      waitedSeconds: Math.floor(waitedMs / 1000),
    });
    await this.notifications.toOps('OPS_DISPATCH_ALERT', {
      reference: order.reference,
      minutes: String(minutes),
    });
  }

  // --- Annonces -----------------------------------------------------------------------------

  private async announceOffer(order: OrderWithPlaces, offer: DispatchOffer, userId: string): Promise<void> {
    const dto = toOfferDto(order, offer);
    this.realtime.toUser(userId, 'offer.new', dto);
    await this.notifications
      .toUser(userId, {
        template: 'OFFER_NEW',
        params: {
          pickup: dto.pickup.neighborhood ?? dto.pickup.landmark,
          dropoff: dto.dropoff.neighborhood ?? dto.dropoff.landmark,
          earning: dto.riderEarning,
        },
        data: { type: 'offer.new', offerId: offer.id, orderId: order.id, expiresAt: dto.expiresAt },
        orderId: order.id,
        urgent: true,
        ttlSeconds: Math.ceil(this.env.DISPATCH_OFFER_TIMEOUT_SECONDS),
      })
      .catch((error: unknown) => {
        this.logger.warn(`Push de proposition non envoyé : ${String(error)}`);
      });
  }

  private async announceClosed(offers: DispatchOffer[]): Promise<void> {
    if (offers.length === 0) return;
    const riders = await this.prisma.riderProfile.findMany({
      where: { id: { in: offers.map((offer) => offer.riderId) } },
      select: { id: true, userId: true },
    });
    const userOf = new Map(riders.map((rider) => [rider.id, rider.userId]));
    for (const offer of offers) {
      const userId = userOf.get(offer.riderId);
      if (!userId) continue;
      this.realtime.toUser(userId, 'offer.closed', {
        offerId: offer.id,
        orderId: offer.orderId,
        outcome: offer.outcome,
      });
    }
  }
}

/** Livreurs qui ont rendu la course (attribuée à la main ou acceptée), à ne plus solliciter. */
async function releasedBy(tx: Prisma.TransactionClient, orderId: string): Promise<string[]> {
  const events = await tx.orderEvent.findMany({
    where: { orderId, fromStatus: 'ASSIGNED', toStatus: 'SEARCHING_RIDER', actorRole: 'RIDER' },
    select: { actorId: true },
  });
  const userIds = events.flatMap((event) => (event.actorId ? [event.actorId] : []));
  if (userIds.length === 0) return [];
  const riders = await tx.riderProfile.findMany({
    where: { userId: { in: userIds } },
    select: { id: true },
  });
  return riders.map((rider) => rider.id);
}

/** Verrou transactionnel propre à une commande : les tours d'attribution s'exécutent un à un. */
async function lockOrder(tx: Prisma.TransactionClient, orderId: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`dispatch:${orderId}`}, 0))`;
}

export function toOfferDto(order: OrderWithPlaces, offer: DispatchOffer): z.output<typeof OfferDto> {
  const place = (address: OrderWithPlaces['pickupAddress']) => ({
    landmark: address.landmark,
    neighborhood: address.neighborhood?.name ?? null,
    latitude: address.latitude,
    longitude: address.longitude,
  });
  return {
    id: offer.id,
    orderId: order.id,
    reference: order.reference,
    expiresAt: offer.expiresAt.toISOString(),
    approachMeters: offer.approachMeters,
    pickup: place(order.pickupAddress),
    dropoff: place(order.dropoffAddress),
    distanceMeters: order.distanceMeters,
    riderEarning: order.riderEarning,
    codAmount: order.codAmount,
    cashFee: order.feePaymentMethod === 'CASH' ? order.totalPrice : 0,
    packageSize: order.packageSize,
    isFragile: order.isFragile,
    isExpress: order.isExpress,
  };
}
