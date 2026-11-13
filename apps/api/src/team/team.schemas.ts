import { z } from 'zod';
import { CameroonMobile } from '../common/phone.js';

export const StaffRoleEnum = z
  .enum(['ADMIN', 'DISPATCHER', 'SUPPORT', 'FINANCE'])
  .meta({ id: 'StaffRole' });
export const STAFF_ROLES = StaffRoleEnum.options;

export const TeamMemberDto = z
  .object({
    id: z.uuid(),
    fullName: z.string().nullable(),
    phone: z.string(),
    roles: z.array(StaffRoleEnum),
    /** Double authentification configurée (application d'authentification). */
    mfaEnabled: z.boolean(),
    /** Dernière connexion ou renouvellement de session. */
    lastActiveAt: z.iso.datetime().nullable(),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'TeamMember' });

export const TeamMemberBody = z.object({
  phone: CameroonMobile,
  fullName: z.string().trim().min(2).max(80),
  roles: z.array(StaffRoleEnum).min(1).max(4),
});

export const TeamRolesBody = z.object({ roles: z.array(StaffRoleEnum).min(1).max(4) });

export const AuditListQuery = z.object({
  /** Type d'objet : order, rider, payout, pricing_grid… */
  entityType: z.string().trim().max(40).optional(),
  actorId: z.uuid().optional(),
  /** Identifiant exact d'un objet (commande, livreur…). */
  entityId: z.string().trim().max(80).optional(),
  cursor: z.uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

export const AuditEntryDto = z
  .object({
    id: z.uuid(),
    at: z.iso.datetime(),
    actor: z
      .object({ id: z.uuid(), name: z.string().nullable(), phone: z.string().nullable() })
      .nullable(),
    actorRoles: z.array(z.string()),
    action: z.string(),
    entityType: z.string(),
    entityId: z.string(),
    before: z.unknown().nullable(),
    after: z.unknown().nullable(),
    ip: z.string().nullable(),
  })
  .meta({ id: 'AuditEntry' });

export const AuditPageDto = z
  .object({
    items: z.array(AuditEntryDto),
    nextCursor: z.uuid().nullable(),
    /** Types d'objets présents dans le journal, pour le filtre. */
    entityTypes: z.array(z.string()),
  })
  .meta({ id: 'AuditPage' });
