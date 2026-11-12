import { Injectable } from '@nestjs/common';
import type { Request } from 'express';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { TokenService } from '../auth/token.service.js';
import { AppError } from '../common/errors/app-error.js';
import type { Prisma, User } from '../generated/prisma/client.js';
import type { UserRole } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  type AuditEntryDto,
  type AuditListQuery,
  type AuditPageDto,
  STAFF_ROLES,
  type TeamMemberBody,
  type TeamMemberDto,
} from './team.schemas.js';

type StaffRole = (typeof STAFF_ROLES)[number];
const isStaff = (role: UserRole): role is StaffRole =>
  (STAFF_ROLES as readonly string[]).includes(role);

/**
 * Équipe et journal d'audit (H8). Un membre se connecte ensuite au back-office avec son
 * numéro (code SMS) puis configure sa double authentification à la première connexion.
 * Toute modification de rôle ferme ses sessions : les nouveaux droits valent tout de suite.
 */
@Injectable()
export class TeamService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    private readonly audit: AuditService,
  ) {}

  async members(): Promise<z.output<typeof TeamMemberDto>[]> {
    const users = await this.prisma.user.findMany({
      where: { roles: { hasSome: [...STAFF_ROLES] }, status: { not: 'DELETED' } },
      orderBy: [{ fullName: 'asc' }, { createdAt: 'asc' }],
    });
    const activity = await this.prisma.refreshToken.groupBy({
      by: ['userId'],
      where: { userId: { in: users.map((user) => user.id) } },
      _max: { createdAt: true },
    });
    const lastOf = new Map(activity.map((row) => [row.userId, row._max.createdAt]));
    return users.map((user) => this.toDto(user, lastOf.get(user.id) ?? null));
  }

  async add(
    actor: AuthUser,
    body: z.output<typeof TeamMemberBody>,
    request: Request,
  ): Promise<z.output<typeof TeamMemberDto>> {
    const existing = await this.prisma.user.findUnique({ where: { phone: body.phone } });
    if (existing?.status === 'DELETED') throw AppError.conflict('TEAM_MEMBER_UNAVAILABLE');
    const roles = [...new Set([...(existing?.roles ?? []), ...body.roles])];
    const user = existing
      ? await this.prisma.user.update({
          where: { id: existing.id },
          data: { roles, fullName: existing.fullName ?? body.fullName },
        })
      : await this.prisma.user.create({
          data: { phone: body.phone, fullName: body.fullName, roles },
        });
    await this.audit.record({
      actor,
      action: 'team.member_added',
      entityType: 'user',
      entityId: user.id,
      before: existing ? { roles: existing.roles.filter(isStaff) } : null,
      after: { roles: user.roles.filter(isStaff), fullName: user.fullName },
      request,
    });
    return this.toDto(user, null);
  }

  async setRoles(
    actor: AuthUser,
    userId: string,
    staffRoles: StaffRole[],
    request: Request,
  ): Promise<z.output<typeof TeamMemberDto>> {
    const user = await this.member(userId);
    if (userId === actor.id && !staffRoles.includes('ADMIN')) {
      throw AppError.unprocessable('TEAM_SELF_DEMOTION');
    }
    if (user.roles.includes('ADMIN') && !staffRoles.includes('ADMIN')) {
      await this.assertAnotherAdmin(userId);
    }
    const roles = [...user.roles.filter((role) => !isStaff(role)), ...new Set(staffRoles)];
    const updated = await this.prisma.$transaction(async (tx) => {
      const saved = await tx.user.update({ where: { id: userId }, data: { roles } });
      await this.tokens.revokeAll(userId, tx);
      await this.audit.record(
        {
          actor,
          action: 'team.roles_changed',
          entityType: 'user',
          entityId: userId,
          before: { roles: user.roles.filter(isStaff) },
          after: { roles: saved.roles.filter(isStaff) },
          request,
        },
        tx,
      );
      return saved;
    });
    return this.toDto(updated, null);
  }

  /** Retire l'accès au back-office : rôles d'équipe, sessions et double authentification. */
  async remove(actor: AuthUser, userId: string, request: Request): Promise<void> {
    if (userId === actor.id) throw AppError.unprocessable('TEAM_SELF_DEMOTION');
    const user = await this.member(userId);
    if (user.roles.includes('ADMIN')) await this.assertAnotherAdmin(userId);
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          roles: user.roles.filter((role) => !isStaff(role)),
          totpSecretEnc: null,
          totpEnabledAt: null,
          totpLastUsedStep: null,
          totpFailedAttempts: 0,
          totpLockedUntil: null,
        },
      });
      await this.tokens.revokeAll(userId, tx);
      await this.audit.record(
        {
          actor,
          action: 'team.member_removed',
          entityType: 'user',
          entityId: userId,
          before: { roles: user.roles.filter(isStaff) },
          after: { roles: [] },
          request,
        },
        tx,
      );
    });
  }

  async auditLog(query: z.output<typeof AuditListQuery>): Promise<z.output<typeof AuditPageDto>> {
    const where: Prisma.AuditLogWhereInput = {
      ...(query.entityType ? { entityType: query.entityType } : {}),
      ...(query.actorId ? { actorId: query.actorId } : {}),
      ...(query.entityId ? { entityId: query.entityId } : {}),
      ...(query.cursor ? { id: { lt: query.cursor } } : {}),
    };
    const [rows, types] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        orderBy: { id: 'desc' },
        take: query.limit + 1,
      }),
      this.prisma.auditLog.findMany({
        distinct: ['entityType'],
        select: { entityType: true },
        orderBy: { entityType: 'asc' },
      }),
    ]);
    const page = rows.slice(0, query.limit);
    const actorIds = [...new Set(page.flatMap((row) => (row.actorId ? [row.actorId] : [])))];
    const actors = await this.prisma.user.findMany({
      where: { id: { in: actorIds } },
      select: { id: true, fullName: true, phone: true },
    });
    const actorOf = new Map(actors.map((user) => [user.id, user]));
    return {
      items: page.map((row): z.output<typeof AuditEntryDto> => {
        const author = row.actorId ? actorOf.get(row.actorId) : undefined;
        return {
          id: row.id,
          at: row.createdAt.toISOString(),
          actor: row.actorId
            ? { id: row.actorId, name: author?.fullName ?? null, phone: author?.phone ?? null }
            : null,
          actorRoles: row.actorRoles,
          action: row.action,
          entityType: row.entityType,
          entityId: row.entityId,
          before: row.before ?? null,
          after: row.after ?? null,
          ip: row.ip,
        };
      }),
      nextCursor: rows.length > query.limit ? (page.at(-1)?.id ?? null) : null,
      entityTypes: types.map((type) => type.entityType),
    };
  }

  private async member(userId: string): Promise<User> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.roles.some(isStaff)) throw AppError.notFound('TEAM_MEMBER_NOT_FOUND');
    return user;
  }

  /** Il reste toujours au moins un administrateur. */
  private async assertAnotherAdmin(userId: string): Promise<void> {
    const others = await this.prisma.user.count({
      where: { roles: { has: 'ADMIN' }, status: 'ACTIVE', id: { not: userId } },
    });
    if (others === 0) throw AppError.unprocessable('TEAM_LAST_ADMIN');
  }

  private toDto(user: User, lastActiveAt: Date | null): z.output<typeof TeamMemberDto> {
    return {
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      roles: user.roles.filter(isStaff),
      mfaEnabled: user.totpEnabledAt !== null,
      lastActiveAt: lastActiveAt?.toISOString() ?? null,
      createdAt: user.createdAt.toISOString(),
    };
  }
}
