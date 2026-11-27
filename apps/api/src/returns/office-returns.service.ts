import { Inject, Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import { hashCode, randomDigits, verifyCode } from '../common/crypto.js';
import { daysLeft, shortDate } from '../common/time.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { OrderEventsBus } from '../events/order-events.bus.js';
import { OrderFinanceService, type ReturnQuote } from '../finance/order-finance.service.js';
import type { Order } from '../generated/prisma/client.js';
import { NotificationService } from '../notifications/notification.service.js';
import { OrderTransitionsService } from '../orders/order-transitions.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { MAX_CODE_FAILURES } from '../rider-app/rider-orders.service.js';
import type { OfficeHandOverBody, OfficeReturnDto } from './office-returns.schemas.js';

const DAY_MS = 86_400_000;

/**
 * Retour sans dette (lot « bureau Tara ») : ce que coûte le retour à l'expéditeur, paiement
 * des frais d'un colis gardé au bureau (solde, rechargé par Mobile Money au besoin, ou
 * espèces au bureau), remise du colis contre le code de retrait, colis non réclamé après la
 * garde, et rappels à l'expéditeur pendant la garde.
 */
@Injectable()
export class OfficeReturnsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly finance: OrderFinanceService,
    private readonly transitions: OrderTransitionsService,
    private readonly bus: OrderEventsBus,
    private readonly notifications: NotificationService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Annoncé avant le choix du retour, puis tant que le colis est gardé au bureau. */
  async quote(user: AuthUser, orderId: string): Promise<ReturnQuote> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (order?.senderId !== user.id) throw AppError.notFound('ORDER_NOT_FOUND');
    if (order.status !== 'DELIVERY_FAILED' && order.status !== 'HELD_AT_OFFICE') {
      throw AppError.conflict('ORDER_NOT_AT_OFFICE');
    }
    return this.finance.returnQuote(order);
  }

  /**
   * L'expéditeur paie les frais de son colis gardé au bureau, avec son solde. S'il ne suffit
   * pas : RETURN_PAYMENT_REQUIRED (l'app propose de recharger ce montant puis rappelle).
   * Payé : un code de retrait part par SMS, à donner au bureau.
   */
  async pay(user: AuthUser, orderId: string): Promise<void> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (order?.senderId !== user.id) throw AppError.notFound('ORDER_NOT_FOUND');
    const code = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT id FROM orders WHERE id = ${orderId}::uuid FOR UPDATE`;
      const fresh = await tx.order.findUniqueOrThrow({ where: { id: orderId } });
      await this.finance.payOffice(tx, fresh, { kind: 'BALANCE' });
      return this.newPickupCode(tx, fresh);
    });
    await this.sendPickupCode(orderId, code);
  }

  /** Colis gardés au bureau, la fin de garde la plus proche d'abord (back-office). */
  async list(now = new Date()): Promise<z.output<typeof OfficeReturnDto>[]> {
    const orders = await this.prisma.order.findMany({
      where: { status: 'HELD_AT_OFFICE' },
      include: {
        sender: {
          select: { fullName: true, phone: true, merchant: { select: { shopName: true } } },
        },
        merchant: { select: { shopName: true } },
      },
      orderBy: { officeUntil: 'asc' },
      take: 500,
    });
    return orders.map((order) => {
      const heldSince = order.officeAt ?? order.updatedAt;
      const until = order.officeUntil ?? heldSince;
      return {
        orderId: order.id,
        reference: order.reference,
        senderName:
          order.merchant?.shopName ?? order.sender.merchant?.shopName ?? order.sender.fullName,
        senderPhone: order.sender.phone,
        heldSince: heldSince.toISOString(),
        until: until.toISOString(),
        daysLeft: daysLeft(until, now),
        due: order.officePaidAt ? 0 : order.officeDue,
        paidAt: order.officePaidAt?.toISOString() ?? null,
        reminders: order.officeReminders,
      };
    });
  }

  /**
   * L'équipe rend le colis à l'expéditeur venu au bureau : contre le code de retrait (payé
   * dans l'app), ou contre les frais en espèces. Tracé.
   */
  async handOver(
    staff: AuthUser,
    orderId: string,
    body: z.output<typeof OfficeHandOverBody>,
    request: Request,
  ): Promise<void> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    if (order.status !== 'HELD_AT_OFFICE') throw AppError.conflict('ORDER_NOT_AT_OFFICE');
    if (body.code !== undefined) {
      if (!order.officePaidAt) {
        throw AppError.conflict('OFFICE_PAYMENT_REQUIRED', { amount: order.officeDue });
      }
      await this.checkPickupCode(order, body.code);
    } else if (order.officePaidAt) {
      // Déjà payé dans l'app : le code de retrait protège l'expéditeur.
      throw AppError.conflict('OFFICE_ALREADY_PAID');
    }
    const change = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT id FROM orders WHERE id = ${orderId}::uuid FOR UPDATE`;
      let fresh = await tx.order.findUniqueOrThrow({ where: { id: orderId } });
      if (body.cashReceived) {
        await this.finance.payOffice(tx, fresh, { kind: 'CASH', staffId: staff.id });
        fresh = await tx.order.findUniqueOrThrow({ where: { id: orderId } });
      }
      const result = await this.transitions.applyIn(
        tx,
        fresh,
        'RETURNED',
        { id: staff.id, role: 'SUPPORT' },
        { note: body.note ?? 'Colis rendu au bureau Tara' },
      );
      await this.audit.record(
        {
          actor: staff,
          action: 'order.office-hand-over',
          entityType: 'order',
          entityId: orderId,
          before: { status: 'HELD_AT_OFFICE', paid: Boolean(order.officePaidAt) },
          after: {
            status: 'RETURNED',
            via: body.cashReceived ? 'CASH' : 'CODE',
            amount: body.cashReceived ? order.officeDue : 0,
          },
          request,
        },
        tx,
      );
      return result.change;
    });
    await this.bus.publish(change);
  }

  /**
   * Garde finie, colis jamais réclamé : Tara en dispose selon les conditions (la note dit
   * quoi). Les frais sont abandonnés : aucune dette.
   */
  async unclaimed(staff: AuthUser, orderId: string, note: string, request: Request): Promise<void> {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    if (order.status !== 'HELD_AT_OFFICE') throw AppError.conflict('ORDER_NOT_AT_OFFICE');
    await this.transitions.apply(orderId, 'UNCLAIMED', { id: staff.id, role: 'SUPPORT' }, { note });
    await this.audit.record({
      actor: staff,
      action: 'order.office-unclaimed',
      entityType: 'order',
      entityId: orderId,
      before: { status: 'HELD_AT_OFFICE', due: order.officeDue },
      after: { status: 'UNCLAIMED', note },
      request,
    });
  }

  @Cron('0 15 * * * *', { name: 'office-reminders' })
  async scheduledReminders(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    await this.sendReminders();
  }

  /**
   * Rappels à l'expéditeur dont le colis attend au bureau sans être payé : aux jours de
   * OFFICE_REMINDER_DAYS après le dépôt, puis un dernier message à la fin de la garde. Un
   * rappel manqué (serveur arrêté) part au passage suivant, une seule fois.
   */
  async sendReminders(now = new Date()): Promise<number> {
    const steps = this.env.OFFICE_REMINDER_DAYS;
    const waiting = await this.prisma.order.findMany({
      where: {
        status: 'HELD_AT_OFFICE',
        officePaidAt: null,
        officeAt: { not: null },
        officeReminders: { lte: steps.length },
      },
      include: { sender: { select: { phone: true, locale: true } } },
      take: 500,
    });
    let sent = 0;
    for (const order of waiting) {
      if (!order.officeAt || !order.officeUntil) continue;
      const days = Math.floor((now.getTime() - order.officeAt.getTime()) / DAY_MS);
      const over = now >= order.officeUntil;
      const due = over ? steps.length + 1 : steps.filter((step) => step <= days).length;
      if (due <= order.officeReminders) continue;
      // Un seul envoi même si deux serveurs passent en même temps.
      const { count } = await this.prisma.order.updateMany({
        where: { id: order.id, officeReminders: order.officeReminders },
        data: { officeReminders: due },
      });
      if (count !== 1) continue;
      const locale = order.sender.locale === 'EN' ? 'en' : 'fr';
      const params = this.officeParams(order, locale, now);
      if (over) {
        await this.notifications.toUser(order.senderId, {
          template: 'OFFICE_HOLD_OVER',
          params,
          data: { type: 'order.status', orderId: order.id, status: order.status },
          orderId: order.id,
        });
        await this.notifications.toPhone({
          phone: order.sender.phone,
          locale,
          userId: order.senderId,
          orderId: order.id,
          template: 'OFFICE_HOLD_OVER',
          params,
        });
      } else {
        await this.notifications.toUser(order.senderId, {
          template: 'OFFICE_REMINDER',
          params,
          data: { type: 'order.status', orderId: order.id, status: order.status },
          orderId: order.id,
        });
        await this.notifications.toPhone({
          phone: order.sender.phone,
          locale,
          userId: order.senderId,
          orderId: order.id,
          template: 'OFFICE_REMINDER',
          params,
        });
      }
      sent++;
    }
    return sent;
  }

  /** Mots des messages sur le bureau : référence, adresse, horaires, montant, délai. */
  officeParams(order: Order, locale: 'fr' | 'en', now = new Date()): Record<string, string> {
    return {
      reference: order.reference,
      address: this.env.OFFICE_ADDRESS,
      hours: locale === 'en' ? this.env.OFFICE_HOURS_EN : this.env.OFFICE_HOURS,
      amount: String(order.officePaidAt ? 0 : order.officeDue),
      until: order.officeUntil ? shortDate(order.officeUntil) : '',
      days: String(order.officeUntil ? daysLeft(order.officeUntil, now) : 0),
    };
  }

  /** Nouveau code de retrait (remplace le code de retour), compteur d'erreurs à zéro. */
  private async newPickupCode(
    tx: Parameters<Parameters<PrismaService['$transaction']>[0]>[0],
    order: Order,
  ): Promise<string> {
    const code = randomDigits(4);
    await tx.order.update({
      where: { id: order.id },
      data: {
        pickupCodeHash: hashCode(this.env.CODE_HASH_SECRET, `pickup:${order.reference}`, code),
        pickupCodeFailures: 0,
      },
    });
    return code;
  }

  private async sendPickupCode(orderId: string, code: string): Promise<void> {
    const order = await this.prisma.order.findUniqueOrThrow({
      where: { id: orderId },
      include: { sender: { select: { phone: true, locale: true } } },
    });
    const locale = order.sender.locale === 'EN' ? 'en' : 'fr';
    const params = this.officeParams(order, locale);
    await this.notifications.toPhone({
      phone: order.sender.phone,
      locale,
      userId: order.senderId,
      orderId,
      template: 'OFFICE_PICKUP_CODE',
      params,
      secretParams: { code },
      smsOnly: true,
    });
    await this.notifications.toUser(order.senderId, {
      template: 'OFFICE_PAID',
      params,
      data: { type: 'order.status', orderId, status: order.status },
      orderId,
    });
  }

  /** Code de retrait vérifié comme les autres codes : bloqué après trop d'erreurs. */
  private async checkPickupCode(order: Order, code: string): Promise<void> {
    if (order.pickupCodeFailures >= MAX_CODE_FAILURES) {
      throw AppError.unprocessable('PICKUP_CODE_LOCKED');
    }
    const purpose = `pickup:${order.reference}`;
    if (
      order.pickupCodeHash &&
      verifyCode(this.env.CODE_HASH_SECRET, purpose, code, order.pickupCodeHash)
    ) {
      return;
    }
    const updated = await this.prisma.order.update({
      where: { id: order.id },
      data: { pickupCodeFailures: { increment: 1 } },
    });
    const remaining = MAX_CODE_FAILURES - updated.pickupCodeFailures;
    if (remaining <= 0) throw AppError.unprocessable('PICKUP_CODE_LOCKED');
    throw AppError.unprocessable('PICKUP_CODE_INVALID', { remaining });
  }
}
