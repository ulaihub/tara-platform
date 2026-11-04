import { Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import { Prisma } from '../generated/prisma/client.js';
import { ZonesRepository } from '../geo/zones.repository.js';
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
    riderPlate: alert.rider.plateNumber,
    orderId: alert.orderId,
    latitude: alert.latitude,
    longitude: alert.longitude,
    accuracy: alert.accuracy,
    neighborhood: alert.neighborhood,
    note: alert.note,
    createdAt: alert.createdAt.toISOString(),
    acknowledgedAt: alert.acknowledgedAt?.toISOString() ?? null,
    policeCalledAt: alert.policeCalledAt?.toISOString() ?? null,
    resolvedAt: alert.resolvedAt?.toISOString() ?? null,
    cancelledAt: alert.cancelledAt?.toISOString() ?? null,
    resolution: alert.resolution,
  };
}

/**
 * Bouton d'alerte du livreur (E8), en deux volets. Équipe Tara : la position part
 * immédiatement au back-office (temps réel) et par SMS aux numéros d'astreinte et au contact
 * d'urgence ; un agent prend en charge et rappelle le livreur. Police : le livreur l'appelle
 * depuis l'écran d'alerte ; s'il ne peut pas, l'agent l'appelle (livreur injoignable ou
 * danger confirmé) et l'appel est enregistré avec l'alerte. Le livreur suit en direct la
 * prise en charge (`safety-alert.status`).
 */
@Injectable()
export class SafetyAlertsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
    private readonly notifications: NotificationService,
    private readonly zones: ZonesRepository,
    private readonly audit: AuditService,
  ) {}

  async raise(
    user: AuthUser,
    body: z.output<typeof SafetyAlertBody>,
  ): Promise<z.output<typeof SafetyAlertDto>> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId: user.id } });
    if (!rider) throw AppError.forbidden();
    // Alerte renvoyée au retour du réseau : la même, sans nouveaux SMS.
    const replay = await this.findReplay(rider.id, body.clientEventId);
    if (replay) return toDto(replay);
    // Une course citée doit être la sienne ; sinon l'alerte part quand même, sans course.
    const order = body.orderId
      ? await this.prisma.order.findFirst({ where: { id: body.orderId, riderId: rider.id } })
      : null;
    const neighborhoods = await this.zones.findContaining(
      body.latitude,
      body.longitude,
      'NEIGHBORHOOD',
    );
    let alert: AlertWithRider;
    try {
      alert = await this.prisma.safetyAlert.create({
        data: {
          riderId: rider.id,
          orderId: order?.id ?? null,
          latitude: body.latitude,
          longitude: body.longitude,
          accuracy: body.accuracy ?? null,
          neighborhood: neighborhoods[0]?.name ?? null,
          note: body.note ?? null,
          clientEventId: body.clientEventId ?? null,
        },
        include: INCLUDE,
      });
    } catch (error) {
      // Deux envois simultanés de la même alerte : le second reprend le premier.
      const raced = await this.findReplay(rider.id, body.clientEventId);
      if (raced && isUniqueViolation(error)) return toDto(raced);
      throw error;
    }
    const dto = toDto(alert);
    this.realtime.toOps('ops.safety-alert', dto);
    const map = `https://maps.google.com/?q=${body.latitude},${body.longitude}`;
    const name = alert.rider.user.fullName ?? 'Livreur';
    await this.notifications.toOps('OPS_SAFETY_ALERT', {
      rider: name,
      phone: alert.rider.user.phone,
      plate: rider.plateNumber ?? '-',
      place: alert.neighborhood ?? '-',
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

  private findReplay(riderId: string, clientEventId: string | undefined) {
    if (!clientEventId) return Promise.resolve(null);
    return this.prisma.safetyAlert.findUnique({
      where: { riderId_clientEventId: { riderId, clientEventId } },
      include: INCLUDE,
    });
  }

  /** Événement aux agents (back-office) et au livreur (suivi de la prise en charge). */
  private broadcast(alert: AlertWithRider): z.output<typeof SafetyAlertDto> {
    const dto = toDto(alert);
    this.realtime.toOps('ops.safety-alert', dto);
    this.realtime.toUser(alert.rider.userId, 'safety-alert.status', dto);
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
    const dto = this.broadcast(updated);
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
    return this.broadcast(updated);
  }

  /**
   * Police appelée par l'agent (livreur injoignable ou danger confirmé) : l'heure, l'agent et
   * ce qui a été dit restent avec l'alerte, et l'action est tracée dans le journal d'audit.
   */
  async policeCalled(
    id: string,
    user: AuthUser,
    note: string,
    request: Request,
  ): Promise<z.output<typeof SafetyAlertDto>> {
    const alert = await this.prisma.safetyAlert.findUnique({ where: { id } });
    if (!alert) throw AppError.notFound('SAFETY_ALERT_NOT_FOUND');
    if (alert.resolvedAt) throw AppError.conflict('SAFETY_ALERT_CLOSED');
    const now = new Date();
    const updated = await this.prisma.safetyAlert.update({
      where: { id },
      data: {
        acknowledgedAt: alert.acknowledgedAt ?? now,
        handledById: alert.handledById ?? user.id,
        policeCalledAt: alert.policeCalledAt ?? now,
        policeCalledById: alert.policeCalledById ?? user.id,
        policeNote: note,
      },
      include: INCLUDE,
    });
    await this.audit.record({
      actor: user,
      action: 'safety-alert.police-called',
      entityType: 'safety_alert',
      entityId: id,
      before: { policeCalledAt: alert.policeCalledAt?.toISOString() ?? null },
      after: { policeCalledAt: updated.policeCalledAt?.toISOString() ?? null, note },
      request,
    });
    return this.broadcast(updated);
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
    return this.broadcast(updated);
  }
}

function isUniqueViolation(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}
