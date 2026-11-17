import { Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { mapLimit } from '../common/concurrency.js';
import { AppError, localizedMessage } from '../common/errors/app-error.js';
import { resolveLocale } from '../common/i18n/locale.js';
import { addDays, addMinutes } from '../common/time.js';
import type {
  PricingGrid,
  PricingSurcharge,
  PricingTier,
  Prisma,
  PromoCode,
} from '../generated/prisma/client.js';
import type { PackageSize, SurchargeCode, VehicleType } from '../generated/prisma/enums.js';
import { AddressesService } from '../geo/addresses.service.js';
import { ZonesRepository } from '../geo/zones.repository.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { DistanceService, type RouteEstimate } from '../routing/distance.service.js';
import { computePrice, type PriceBreakdown, vehicleForParcel } from './pricing.engine.js';
import type {
  BatchQuoteBody,
  BatchQuoteDto,
  PointRef,
  PricingGridBody,
  PricingGridDto,
  QuoteBody,
  QuoteDto,
} from './pricing.schemas.js';
import { PricingSettingsService } from './pricing-settings.service.js';
import { PromoService } from './promo.service.js';

type GridWithRules = PricingGrid & { tiers: PricingTier[]; surcharges: PricingSurcharge[] };

export interface ResolvedPoint {
  latitude: number;
  longitude: number;
  city: string;
  addressId: string | null;
}

export interface QuoteInput {
  pickup: z.output<typeof PointRef>;
  dropoff: z.output<typeof PointRef>;
  packageSize: PackageSize;
  isExpress: boolean;
  loadingHelp?: boolean | undefined;
  scheduledFor?: string | undefined;
  promoCode?: string | undefined;
}

export interface FullQuote {
  grid: GridWithRules;
  pickup: ResolvedPoint;
  dropoff: ResolvedPoint;
  route: RouteEstimate;
  promo: PromoCode | null;
  price: PriceBreakdown;
  scheduledFor: Date | null;
}

export const MIN_SCHEDULE_DELAY_MINUTES = 30;
export const MAX_SCHEDULE_DAYS = 7;

export function toGridDto(grid: GridWithRules): z.output<typeof PricingGridDto> {
  return {
    id: grid.id,
    name: grid.name,
    city: grid.city,
    vehicleType: grid.vehicleType,
    riderShareBps: grid.riderShareBps,
    perKmBeyondLastTier: grid.perKmBeyondLastTier,
    active: grid.active,
    validFrom: grid.validFrom.toISOString(),
    validTo: grid.validTo?.toISOString() ?? null,
    tiers: [...grid.tiers]
      .sort((a, b) => a.upToMeters - b.upToMeters)
      .map((t) => ({ upToMeters: t.upToMeters, price: t.price })),
    surcharges: [...grid.surcharges]
      .sort((a, b) => a.code.localeCompare(b.code))
      .map((s) => ({ code: s.code, amount: s.amount, percentBps: s.percentBps, active: s.active })),
    createdAt: grid.createdAt.toISOString(),
  };
}

/** Devis (C2) et administration des grilles tarifaires versionnées (C7). */
/** Prix calculés en même temps pour une liste d'envoi (itinéraires demandés en parallèle). */
export const QUOTE_CONCURRENCY = 8;

@Injectable()
export class PricingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly addresses: AddressesService,
    private readonly zones: ZonesRepository,
    private readonly distance: DistanceService,
    private readonly promos: PromoService,
    private readonly settings: PricingSettingsService,
    private readonly audit: AuditService,
  ) {}

  async activeGrid(city: string, vehicleType: VehicleType, at: Date): Promise<GridWithRules> {
    const grid = await this.prisma.pricingGrid.findFirst({
      where: {
        city,
        vehicleType,
        active: true,
        validFrom: { lte: at },
        OR: [{ validTo: null }, { validTo: { gt: at } }],
      },
      orderBy: { validFrom: 'desc' },
      include: { tiers: true, surcharges: true },
    });
    if (!grid) throw AppError.unprocessable('PRICING_UNAVAILABLE', { city });
    return grid;
  }

  async resolvePoint(user: AuthUser, ref: z.output<typeof PointRef>): Promise<ResolvedPoint> {
    if ('addressId' in ref) {
      const address = await this.addresses.usableBy(user, ref.addressId);
      return {
        latitude: address.latitude,
        longitude: address.longitude,
        city: address.city,
        addressId: address.id,
      };
    }
    const area = (await this.zones.findContaining(ref.latitude, ref.longitude, 'SERVICE_AREA'))[0];
    if (!area) throw AppError.unprocessable('OUT_OF_SERVICE_AREA');
    return { latitude: ref.latitude, longitude: ref.longitude, city: area.city, addressId: null };
  }

  /** Vérifie le créneau programmé : entre 30 minutes et 7 jours (C3). */
  scheduleFrom(value: string | undefined, now: Date): Date | null {
    if (!value) return null;
    const at = new Date(value);
    if (at < addMinutes(now, MIN_SCHEDULE_DELAY_MINUTES) || at > addDays(now, MAX_SCHEDULE_DAYS)) {
      throw AppError.unprocessable('SCHEDULE_INVALID');
    }
    return at;
  }

  /** Calcul complet côté serveur ; le prix envoyé par une app n'est jamais utilisé. */
  async quote(
    user: AuthUser,
    input: QuoteInput,
    tx?: Prisma.TransactionClient,
  ): Promise<FullQuote> {
    const now = new Date();
    const scheduledFor = this.scheduleFrom(input.scheduledFor, now);
    const pickup = await this.resolvePoint(user, input.pickup);
    const dropoff = await this.resolvePoint(user, input.dropoff);
    if (pickup.addressId && pickup.addressId === dropoff.addressId) {
      throw AppError.unprocessable('SAME_PICKUP_AND_DROPOFF');
    }
    const at = scheduledFor ?? now;
    const vehicle = vehicleForParcel(input.packageSize);
    const grid = await this.activeGrid(pickup.city, vehicle, at).catch((error: unknown) => {
      // Pas de grille tricycle active : l'offre gros objet n'est pas encore ouverte.
      if (vehicle !== 'MOTORBIKE' && error instanceof AppError) {
        throw AppError.unprocessable('BULKY_UNAVAILABLE', { city: pickup.city });
      }
      throw error;
    });
    const route = await this.distance.route(pickup, dropoff);
    const promo = input.promoCode
      ? await this.promos.validate(input.promoCode, user.id, now, tx)
      : null;
    // Tarif pro (H4) : une boutique paie moins selon ses livraisons réussies du mois.
    const merchant = await (tx ?? this.prisma).merchantProfile.findUnique({
      where: { userId: user.id },
      select: { id: true },
    });
    const volumeDiscountBps = merchant
      ? await this.settings.volumeDiscountBps(merchant.id, pickup.city, now, tx)
      : 0;
    const price = computePrice(grid, {
      distanceMeters: route.meters,
      packageSize: input.packageSize,
      isExpress: input.isExpress,
      loadingHelp: input.packageSize === 'BULKY' && input.loadingHelp === true,
      at,
      promo,
      volumeDiscountBps,
    });
    // Le tarif pro l'emporte : le code promo n'est pas consommé.
    const usedPromo = price.discountSource === 'PROMO' ? promo : null;
    return { grid, pickup, dropoff, route, promo: usedPromo, price, scheduledFor };
  }

  toQuoteDto(quote: FullQuote): z.output<typeof QuoteDto> {
    return {
      city: quote.pickup.city,
      currency: 'XAF',
      distanceMeters: quote.route.meters,
      distanceSource: quote.route.source,
      estimatedMinutes: quote.route.seconds === null ? null : Math.ceil(quote.route.seconds / 60),
      vehicleType: quote.grid.vehicleType,
      basePrice: quote.price.basePrice,
      surcharges: quote.price.surcharges,
      discountTotal: quote.price.discountTotal,
      discountSource: quote.price.discountSource,
      proDiscountBps: quote.price.proDiscountBps,
      totalPrice: quote.price.totalPrice,
      promoCode: quote.promo?.code ?? null,
      retryFee: quote.price.retryFee,
      returnFee: quote.price.returnFee,
    };
  }

  async publicQuote(
    user: AuthUser,
    body: z.output<typeof QuoteBody>,
  ): Promise<z.output<typeof QuoteDto>> {
    return this.toQuoteDto(await this.quote(user, body));
  }

  /**
   * Prix de chaque colis d'une liste d'envoi (C4). Calculés quelques-uns à la fois pour ne
   * pas saturer l'itinéraire ; l'erreur d'un colis (hors zone…) reste attachée à ce colis.
   */
  async publicQuoteMany(
    user: AuthUser,
    body: z.output<typeof BatchQuoteBody>,
  ): Promise<z.output<typeof BatchQuoteDto>> {
    const locale = resolveLocale(undefined, user.locale);
    const items = await mapLimit(body.items, QUOTE_CONCURRENCY, async (item) => {
      try {
        const quote = await this.quote(user, {
          pickup: { addressId: body.pickupAddressId },
          dropoff: { addressId: item.dropoffAddressId },
          packageSize: item.packageSize,
          isExpress: body.isExpress,
          loadingHelp: item.loadingHelp,
          scheduledFor: body.scheduledFor,
        });
        return { quote: this.toQuoteDto(quote), error: null };
      } catch (error) {
        if (!(error instanceof AppError)) throw error;
        return {
          quote: null,
          error: { code: error.code, message: localizedMessage(error, locale) },
        };
      }
    });
    return {
      items,
      totalPrice: items.reduce((sum, item) => sum + (item.quote?.totalPrice ?? 0), 0),
    };
  }

  // --- Administration (C7) ------------------------------------------------------------

  async listGrids(city: string | undefined): Promise<z.output<typeof PricingGridDto>[]> {
    const grids = await this.prisma.pricingGrid.findMany({
      where: city ? { city } : {},
      orderBy: [{ city: 'asc' }, { createdAt: 'desc' }],
      include: { tiers: true, surcharges: true },
      take: 100,
    });
    return grids.map(toGridDto);
  }

  async createGrid(
    actor: AuthUser,
    body: z.output<typeof PricingGridBody>,
    request: Request,
  ): Promise<z.output<typeof PricingGridDto>> {
    const grid = await this.prisma.$transaction(async (tx) => {
      const created = await tx.pricingGrid.create({
        data: {
          name: body.name,
          city: body.city,
          vehicleType: body.vehicleType,
          riderShareBps: body.riderShareBps,
          perKmBeyondLastTier: body.perKmBeyondLastTier,
          validFrom: new Date(),
          createdById: actor.id,
          tiers: { create: body.tiers },
          surcharges: {
            create: body.surcharges.map((s) => ({
              code: s.code,
              amount: s.amount ?? null,
              percentBps: s.percentBps ?? null,
              active: s.active,
            })),
          },
        },
        include: { tiers: true, surcharges: true },
      });
      await this.audit.record(
        {
          actor,
          action: 'pricing_grid.created',
          entityType: 'pricing_grid',
          entityId: created.id,
          after: toGridDto(created),
          request,
        },
        tx,
      );
      return body.activate ? this.activateIn(tx, actor, created.id, request) : created;
    });
    return toGridDto(grid);
  }

  async activate(
    actor: AuthUser,
    gridId: string,
    request: Request,
  ): Promise<z.output<typeof PricingGridDto>> {
    const grid = await this.prisma.$transaction((tx) =>
      this.activateIn(tx, actor, gridId, request),
    );
    return toGridDto(grid);
  }

  /**
   * Une seule grille active par ville et type de véhicule : l'ancienne est archivée avec sa
   * date de fin. Les commandes gardent la grille qui a servi à les tarifer.
   */
  private async activateIn(
    tx: Prisma.TransactionClient,
    actor: AuthUser,
    gridId: string,
    request: Request,
  ): Promise<GridWithRules> {
    const grid = await tx.pricingGrid.findUnique({ where: { id: gridId } });
    if (!grid) throw AppError.notFound('PRICING_GRID_NOT_FOUND');
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${`pricing:${grid.city}:${grid.vehicleType}`}))`;
    const now = new Date();
    await tx.pricingGrid.updateMany({
      where: { city: grid.city, vehicleType: grid.vehicleType, active: true, id: { not: gridId } },
      data: { active: false, validTo: now },
    });
    const activated = await tx.pricingGrid.update({
      where: { id: gridId },
      data: { active: true, validFrom: now, validTo: null },
      include: { tiers: true, surcharges: true },
    });
    await this.audit.record(
      {
        actor,
        action: 'pricing_grid.activated',
        entityType: 'pricing_grid',
        entityId: gridId,
        request,
      },
      tx,
    );
    return activated;
  }

  /** Active ou coupe un supplément sans nouvelle version de grille (ex. pluie forte, C7). */
  async toggleSurcharge(
    actor: AuthUser,
    gridId: string,
    code: SurchargeCode,
    active: boolean,
    request: Request,
  ): Promise<z.output<typeof PricingGridDto>> {
    const { count } = await this.prisma.pricingSurcharge.updateMany({
      where: { gridId, code },
      data: { active },
    });
    if (count !== 1) throw AppError.notFound('PRICING_GRID_NOT_FOUND');
    await this.audit.record({
      actor,
      action: 'pricing_surcharge.toggled',
      entityType: 'pricing_grid',
      entityId: gridId,
      after: { code, active },
      request,
    });
    const grid = await this.prisma.pricingGrid.findUniqueOrThrow({
      where: { id: gridId },
      include: { tiers: true, surcharges: true },
    });
    return toGridDto(grid);
  }
}
