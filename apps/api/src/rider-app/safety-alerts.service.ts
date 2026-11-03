import { Injectable } from '@nestjs/common';
import type { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import type { Prisma } from '../generated/prisma/client.js';
import { NotificationService } from '../notifications/notification.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type { SafetyAlertBody, SafetyAlertDto } from './rider-app.schemas.js';

const INCLUDE = {
  rider: { include: { user: { select: { fullName: true, phone: true } } } },
} as const satisfies Prisma.SafetyAlertInclude;

type AlertWithRider = Prisma.SafetyAlertGetPayload<{ include: typeof INCLUDE }>;

function toDto(alert: AlertWithRider): z.output<typeof SafetyAlertDto> {
  return {
    id: alert.id,
    riderId: alert.riderId,
    riderName: alert.rider.user.fullName,
    riderPhone: alert.rider.user.phone,
    orderId: alert.orderId,
    latitude: alert.latitude,
    longitude: alert.longitude,
    note: alert.note,
    createdAt: alert.createdAt.toISOString(),
    acknowledgedAt: alert.acknowledgedAt?.toISOString() ?? null,
    resolvedAt: alert.resolvedAt?.toISOString() ?? null,
    cancelledAt: alert.cancelledAt?.toISOString() ?? null,
    resolution: alert.resolution,
  };
}

/**
 * Bouton d'alerte du livreur (E8) : la position part immédiatement au back-office (temps
 * réel) et par SMS aux numéros d'astreinte. L'équipe prend en charge puis clôt l'alerte.
 */
@Injectable()
export class SafetyAlertsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
    private readonly notifications: NotificationService,
  ) {}

  async raise(
    user: AuthUser,
    body: z.output<typeof SafetyAlertBody>,
  ): Promise<z.output<typeof SafetyAlertDto>> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId: user.id } });
    if (!rider) throw AppError.forbidden();
    // Une course citée doit être la sienne ; sinon l'alerte part quand même, sans course.
    const order = body.orderId
      ? await this.prisma.order.findFirst({ where: { id: body.orderId, riderId: rider.id } })
      : null;
    const alert = await this.prisma.safetyAlert.create({
      data: {
        riderId: rider.id,
        orderId: order?.id ?? null,
        latitude: body.latitude,
        longitude: body.longitude,
        note: body.note ?? null,
      },
      include: INCLUDE,
    });
    const dto = toDto(alert);
    this.realtime.toOps('ops.safety-alert', dto);
    const map = `https://maps.google.com/?q=${body.latitude},${body.longitude}`;
    const name = alert.rider.user.fullName ?? 'Livreur';
    await this.notifications.toOps('OPS_SAFETY_ALERT', {
      rider: name,
      phone: alert.rider.user.phone,
      map,
    });
    if (rider.emergencyContactPhone) {
      await this.notifications.toPhone({
        phone: rider.emergencyContactPhone,
        template: 'EMERGENCY_CONTACT_ALERT',
        locale: 'fr',
        params: { rider: name, map },
        smsOnly: true,
      });
    }
    return dto;
  }

  /**
   * Annulation par le livreur (fausse manœuvre, danger écarté). L'alerte n'est pas effacée :
   * elle reste ouverte au dispatch, marquée annulée, et l'équipe rappelle le livreur, au cas
   * où l'annulation lui aurait été imposée.
   */
  async cancel(user: AuthUser, id: string): Promise<z.output<typeof SafetyAlertDto>> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId: user.id } });
    const alert = rider
      ? await this.prisma.safetyAlert.findFirst({ where: { id, riderId: rider.id } })
      : null;
    if (!rider || !alert) throw AppError.notFound('SAFETY_ALERT_NOT_FOUND');
    if (alert.cancelledAt || alert.resolvedAt) throw AppError.conflict('SAFETY_ALERT_CLOSED');
    const updated = await this.prisma.safetyAlert.update({
      where: { id },
      data: { cancelledAt: new Date() },
      include: INCLUDE,
    });
    const dto = toDto(updated);
    this.realtime.toOps('ops.safety-alert', dto);
    const name = updated.rider.user.fullName ?? 'Livreur';
    await this.notifications.toOps('OPS_SAFETY_ALERT_CANCELLED', {
      rider: name,
      phone: updated.rider.user.phone,
    });
    if (rider.emergencyContactPhone) {
      await this.notifications.toPhone({
        phone: rider.emergencyContactPhone,
        template: 'EMERGENCY_CONTACT_ALERT_CANCELLED',
        locale: 'fr',
        params: { rider: name },
        smsOnly: true,
      });
    }
    return dto;
  }

  async list(status: 'open' | 'all'): Promise<z.output<typeof SafetyAlertDto>[]> {
    const alerts = await this.prisma.safetyAlert.findMany({
      where: status === 'open' ? { resolvedAt: null } : {},
      include: INCLUDE,
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return alerts.map(toDto);
  }

  async acknowledge(id: string, user: AuthUser): Promise<z.output<typeof SafetyAlertDto>> {
    const alert = await this.prisma.safetyAlert.findUnique({ where: { id } });
    if (!alert) throw AppError.notFound('SAFETY_ALERT_NOT_FOUND');
    const updated = await this.prisma.safetyAlert.update({
      where: { id },
      data: { acknowledgedAt: alert.acknowledgedAt ?? new Date(), handledById: user.id },
      include: INCLUDE,
    });
    const dto = toDto(updated);
    this.realtime.toOps('ops.safety-alert', dto);
    return dto;
  }

  async resolve(
    id: string,
    user: AuthUser,
    resolution: string,
  ): Promise<z.output<typeof SafetyAlertDto>> {
    const alert = await this.prisma.safetyAlert.findUnique({ where: { id } });
    if (!alert) throw AppError.notFound('SAFETY_ALERT_NOT_FOUND');
    const now = new Date();
    const updated = await this.prisma.safetyAlert.update({
      where: { id },
      data: {
        acknowledgedAt: alert.acknowledgedAt ?? now,
        resolvedAt: alert.resolvedAt ?? now,
        handledById: user.id,
        resolution,
      },
      include: INCLUDE,
    });
    const dto = toDto(updated);
    this.realtime.toOps('ops.safety-alert', dto);
    return dto;
  }
}
