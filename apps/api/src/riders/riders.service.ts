import { Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { AppError } from '../common/errors/app-error.js';
import { pageOf } from '../common/pagination.js';
import { cameroonDate } from '../common/time.js';
import type { KycDocument, RiderProfile } from '../generated/prisma/client.js';
import type { KycDocumentType } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { MediaService, type UploadedMedia } from '../storage/media.service.js';
import {
  type AdminRiderDto,
  type AdminRiderListQuery,
  type ApplyRiderBody,
  type EmergencyContactBody,
  type KycDocumentDto,
  REQUIRED_DOCUMENTS,
  type ReviewDocumentBody,
  type RiderDecisionBody,
  type RiderProfileDto,
  type UploadDocumentBody,
} from './riders.schemas.js';

type RiderWithDocuments = RiderProfile & { documents: KycDocument[] };

function toDocumentDto(doc: KycDocument): z.output<typeof KycDocumentDto> {
  return {
    id: doc.id,
    type: doc.type,
    status: doc.status,
    expiresOn: doc.expiresOn ? doc.expiresOn.toISOString().slice(0, 10) : null,
    rejectionReason: doc.rejectionReason,
    createdAt: doc.createdAt.toISOString(),
    reviewedAt: doc.reviewedAt?.toISOString() ?? null,
  };
}

/** Dernière pièce envoyée pour chaque type. */
function latestByType(documents: KycDocument[]): Map<KycDocumentType, KycDocument> {
  const latest = new Map<KycDocumentType, KycDocument>();
  for (const doc of [...documents].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())) {
    if (!latest.has(doc.type)) latest.set(doc.type, doc);
  }
  return latest;
}

function isValidOn(doc: KycDocument | undefined, statuses: string[], today: string): boolean {
  if (!doc || !statuses.includes(doc.status)) return false;
  return !doc.expiresOn || doc.expiresOn.toISOString().slice(0, 10) >= today;
}

/** Groupes de pièces non couverts par une pièce aux statuts donnés et non expirée. */
export function uncoveredDocuments(
  documents: KycDocument[],
  statuses: string[],
  today: string,
): KycDocumentType[] {
  const latest = latestByType(documents);
  return REQUIRED_DOCUMENTS.filter(
    (group) => !group.some((type) => isValidOn(latest.get(type), statuses, today)),
  ).map((group) => group[0] as KycDocumentType);
}

@Injectable()
export class RidersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly audit: AuditService,
  ) {}

  private toProfileDto(rider: RiderWithDocuments): z.output<typeof RiderProfileDto> {
    const today = cameroonDate(new Date());
    return {
      id: rider.id,
      status: rider.status,
      vehicleType: rider.vehicleType,
      plateNumber: rider.plateNumber,
      cashLimit: rider.cashLimit,
      guarantorName: rider.guarantorName,
      guarantorPhone: rider.guarantorPhone,
      emergencyContact:
        rider.emergencyContactName && rider.emergencyContactPhone
          ? { name: rider.emergencyContactName, phone: rider.emergencyContactPhone }
          : null,
      approvedAt: rider.approvedAt?.toISOString() ?? null,
      suspendedReason: rider.suspendedReason,
      documents: [...latestByType(rider.documents).values()].map(toDocumentDto),
      missingDocuments: uncoveredDocuments(rider.documents, ['PENDING', 'APPROVED'], today),
    };
  }

  /** Le contact d'urgence doit pouvoir être joint à la place du livreur, pas le livreur. */
  private checkEmergencyContact(actor: AuthUser, phone: string): void {
    if (phone === actor.phone) throw AppError.unprocessable('EMERGENCY_CONTACT_IS_SELF');
  }

  /** Ajout, changement (contact donné) ou retrait (null) du contact d'urgence. */
  async setEmergencyContact(
    actor: AuthUser,
    contact: z.output<typeof EmergencyContactBody> | null,
    request: Request,
  ): Promise<z.output<typeof RiderProfileDto>> {
    if (contact) this.checkEmergencyContact(actor, contact.phone);
    const before = await this.load({ userId: actor.id });
    const rider = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.riderProfile.update({
        where: { id: before.id },
        data: {
          emergencyContactName: contact?.name ?? null,
          emergencyContactPhone: contact?.phone ?? null,
        },
        include: { documents: true },
      });
      await this.audit.record(
        {
          actor,
          action: 'rider.emergency_contact_changed',
          entityType: 'rider_profile',
          entityId: before.id,
          before: { emergencyContactName: before.emergencyContactName },
          after: { emergencyContactName: updated.emergencyContactName },
          request,
        },
        tx,
      );
      return updated;
    });
    return this.toProfileDto(rider);
  }

  private async load(where: { id: string } | { userId: string }): Promise<RiderWithDocuments> {
    const rider = await this.prisma.riderProfile.findUnique({
      where,
      include: { documents: true },
    });
    if (!rider) throw AppError.notFound('RIDER_NOT_FOUND');
    return rider;
  }

  /** Candidature livreur (A3) : le profil reste en attente jusqu'à validation. */
  async apply(
    actor: AuthUser,
    body: z.output<typeof ApplyRiderBody>,
    request: Request,
  ): Promise<z.output<typeof RiderProfileDto>> {
    const existing = await this.prisma.riderProfile.findUnique({ where: { userId: actor.id } });
    if (existing) throw AppError.conflict('RIDER_ALREADY_APPLIED');
    if (body.emergencyContact) this.checkEmergencyContact(actor, body.emergencyContact.phone);

    const rider = await this.prisma.$transaction(async (tx) => {
      const created = await tx.riderProfile.create({
        data: {
          userId: actor.id,
          vehicleType: body.vehicleType,
          plateNumber: body.plateNumber ?? null,
          guarantorName: body.guarantorName,
          guarantorPhone: body.guarantorPhone,
          emergencyContactName: body.emergencyContact?.name ?? null,
          emergencyContactPhone: body.emergencyContact?.phone ?? null,
        },
        include: { documents: true },
      });
      if (!actor.roles.includes('RIDER')) {
        await tx.user.update({
          where: { id: actor.id },
          data: { roles: { set: [...actor.roles, 'RIDER'] } },
        });
      }
      await this.audit.record(
        {
          actor,
          action: 'rider.applied',
          entityType: 'rider_profile',
          entityId: created.id,
          after: created,
          request,
        },
        tx,
      );
      return created;
    });
    return this.toProfileDto(rider);
  }

  async myProfile(userId: string): Promise<z.output<typeof RiderProfileDto>> {
    return this.toProfileDto(await this.load({ userId }));
  }

  async uploadDocument(
    actor: AuthUser,
    body: z.output<typeof UploadDocumentBody>,
    file: UploadedMedia,
  ): Promise<z.output<typeof KycDocumentDto>> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId: actor.id } });
    if (!rider) throw AppError.notFound('RIDER_NOT_FOUND');
    if (rider.status === 'REJECTED') throw AppError.forbidden();

    const stored = await this.media.store(actor.id, 'KYC_DOCUMENT', file);
    const doc = await this.prisma.kycDocument.create({
      data: {
        riderId: rider.id,
        type: body.type,
        storageKey: stored.key,
        expiresOn: body.expiresOn ? new Date(`${body.expiresOn}T00:00:00Z`) : null,
      },
    });
    return toDocumentDto(doc);
  }

  // --- Back-office (H3) -------------------------------------------------------------

  async list(
    query: z.output<typeof AdminRiderListQuery>,
  ): Promise<{ items: z.output<typeof AdminRiderDto>[]; nextCursor: string | null }> {
    const rows = await this.prisma.riderProfile.findMany({
      where: {
        ...(query.status ? { status: query.status } : {}),
        ...(query.cursor ? { id: { lt: query.cursor } } : {}),
      },
      orderBy: { id: 'desc' },
      take: query.limit + 1,
      include: { documents: true, user: true },
    });
    const page = pageOf(rows, query.limit);
    return {
      items: page.items.map((rider) => this.toAdminDto(rider)),
      nextCursor: page.nextCursor,
    };
  }

  async get(riderId: string): Promise<z.output<typeof AdminRiderDto>> {
    const rider = await this.prisma.riderProfile.findUnique({
      where: { id: riderId },
      include: { documents: true, user: true },
    });
    if (!rider) throw AppError.notFound('RIDER_NOT_FOUND');
    return this.toAdminDto(rider);
  }

  private toAdminDto(
    rider: RiderWithDocuments & { user: { id: string; phone: string; fullName: string | null } },
  ): z.output<typeof AdminRiderDto> {
    return {
      ...this.toProfileDto(rider),
      user: { id: rider.user.id, phone: rider.user.phone, fullName: rider.user.fullName },
      createdAt: rider.createdAt.toISOString(),
      documentHistory: [...rider.documents]
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
        .map(toDocumentDto),
    };
  }

  /** Contenu déchiffré d'une pièce. Chaque consultation est tracée. */
  async documentFile(
    actor: AuthUser,
    documentId: string,
    request: Request,
  ): Promise<{ buffer: Buffer; mimeType: string }> {
    const doc = await this.prisma.kycDocument.findUnique({ where: { id: documentId } });
    if (!doc) throw AppError.notFound('KYC_DOCUMENT_NOT_FOUND');
    await this.audit.record({
      actor,
      action: 'kyc_document.viewed',
      entityType: 'kyc_document',
      entityId: doc.id,
      request,
    });
    return this.media.read(doc.storageKey);
  }

  async reviewDocument(
    actor: AuthUser,
    documentId: string,
    body: z.output<typeof ReviewDocumentBody>,
    request: Request,
  ): Promise<z.output<typeof KycDocumentDto>> {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.kycDocument.findUnique({ where: { id: documentId } });
      if (!before) throw AppError.notFound('KYC_DOCUMENT_NOT_FOUND');
      const { count } = await tx.kycDocument.updateMany({
        where: { id: documentId, status: 'PENDING' },
        data: {
          status: body.decision,
          reviewedById: actor.id,
          reviewedAt: new Date(),
          rejectionReason: body.decision === 'REJECTED' ? (body.rejectionReason ?? null) : null,
          ...(body.expiresOn ? { expiresOn: new Date(`${body.expiresOn}T00:00:00Z`) } : {}),
        },
      });
      if (count !== 1) throw AppError.conflict('KYC_DOCUMENT_ALREADY_REVIEWED');
      const after = await tx.kycDocument.findUniqueOrThrow({ where: { id: documentId } });
      await this.audit.record(
        {
          actor,
          action: `kyc_document.${body.decision.toLowerCase()}`,
          entityType: 'kyc_document',
          entityId: documentId,
          before,
          after,
          request,
        },
        tx,
      );
      return toDocumentDto(after);
    });
  }

  /** Décision sur le livreur : validation, refus, suspension ou réactivation (H3). */
  async decide(
    actor: AuthUser,
    riderId: string,
    body: z.output<typeof RiderDecisionBody>,
    request: Request,
  ): Promise<z.output<typeof AdminRiderDto>> {
    const rider = await this.load({ id: riderId });
    const allowed: Record<typeof body.decision, string[]> = {
      APPROVE: ['PENDING'],
      REJECT: ['PENDING'],
      SUSPEND: ['ACTIVE'],
      REACTIVATE: ['SUSPENDED'],
    };
    if (!allowed[body.decision].includes(rider.status)) {
      throw AppError.conflict('RIDER_DECISION_INVALID', { status: rider.status });
    }
    if (body.decision === 'APPROVE' || body.decision === 'REACTIVATE') {
      const missing = uncoveredDocuments(rider.documents, ['APPROVED'], cameroonDate(new Date()));
      if (missing.length > 0) {
        throw AppError.unprocessable(
          'RIDER_DOCUMENTS_INCOMPLETE',
          { missing: missing.join(', ') },
          { missing },
        );
      }
    }

    const now = new Date();
    const data =
      body.decision === 'APPROVE'
        ? { status: 'ACTIVE' as const, approvedAt: now, approvedById: actor.id }
        : body.decision === 'REJECT'
          ? { status: 'REJECTED' as const }
          : body.decision === 'SUSPEND'
            ? { status: 'SUSPENDED' as const, suspendedReason: body.reason ?? null }
            : { status: 'ACTIVE' as const, suspendedReason: null };

    await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.riderProfile.updateMany({
        where: { id: riderId, status: rider.status },
        data,
      });
      if (count !== 1) throw AppError.conflict('RIDER_DECISION_INVALID', { status: rider.status });
      await this.audit.record(
        {
          actor,
          action: `rider.${body.decision.toLowerCase()}`,
          entityType: 'rider_profile',
          entityId: riderId,
          before: { status: rider.status },
          after: { ...data, reason: body.reason ?? null },
          request,
        },
        tx,
      );
    });
    return this.get(riderId);
  }
}
