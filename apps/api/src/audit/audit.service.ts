import { Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { AuthUser } from '../auth/auth.types.js';
import type { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface AuditEntry {
  actor: AuthUser | null;
  /** Verbe au format « entité.action », ex. « rider.approved ». */
  action: string;
  entityType: string;
  entityId: string;
  before?: unknown;
  after?: unknown;
  request?: Request;
}

/** Convertit une valeur (dates comprises) en JSON stockable. */
function toJson(value: unknown): Prisma.InputJsonValue | undefined {
  return value === undefined
    ? undefined
    : (JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue);
}

/** Journal d'audit des actions sensibles (H8). La table est en ajout seul. */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async record(entry: AuditEntry, tx?: Prisma.TransactionClient): Promise<void> {
    const client = tx ?? this.prisma;
    await client.auditLog.create({
      data: {
        actorId: entry.actor?.id ?? null,
        actorRoles: entry.actor?.roles ?? [],
        action: entry.action,
        entityType: entry.entityType,
        entityId: entry.entityId,
        before: toJson(entry.before),
        after: toJson(entry.after),
        ip: entry.request?.ip ?? null,
        userAgent: entry.request?.headers['user-agent']?.slice(0, 500) ?? null,
      },
    });
  }
}
