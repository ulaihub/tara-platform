import { z } from 'zod';
import { CameroonMobile } from '../common/phone.js';

export const UserRoleEnum = z
  .enum(['CUSTOMER', 'MERCHANT', 'RIDER', 'DISPATCHER', 'SUPPORT', 'FINANCE', 'ADMIN'])
  .meta({ id: 'UserRole' });
export const MobileMoneyOperatorEnum = z
  .enum(['MTN', 'ORANGE'])
  .meta({ id: 'MobileMoneyOperator' });

export const MerchantDto = z
  .object({
    id: z.uuid(),
    shopName: z.string(),
    category: z.string().nullable(),
    payoutPhone: z.string(),
    payoutOperator: MobileMoneyOperatorEnum,
    payoutSchedule: z.enum(['DAILY', 'ON_DEMAND']),
    plan: z.enum(['FREE', 'PRO', 'BUSINESS']),
    rccm: z.string().nullable(),
    niu: z.string().nullable(),
  })
  .meta({ id: 'Merchant' });

export const MeDto = z
  .object({
    id: z.uuid(),
    phone: z.string(),
    fullName: z.string().nullable(),
    locale: z.enum(['FR', 'EN']),
    roles: z.array(UserRoleEnum),
    referralCode: z.string().nullable(),
    createdAt: z.iso.datetime(),
    merchant: MerchantDto.nullable(),
    rider: z
      .object({
        id: z.uuid(),
        status: z.enum(['PENDING', 'ACTIVE', 'SUSPENDED', 'REJECTED']),
        vehicleType: z.enum(['MOTORBIKE', 'TRICYCLE', 'CAR']),
      })
      .nullable(),
    /**
     * Membre de l'équipe (back-office) : second facteur enrôlé, et vérifié pour cette
     * session (sinon les routes de l'équipe répondent MFA_REQUIRED). Null sinon.
     */
    staff: z.object({ mfaEnrolled: z.boolean(), mfaVerified: z.boolean() }).nullable(),
  })
  .meta({ id: 'Me' });

export const UpdateMeBody = z
  .object({
    fullName: z.string().trim().min(2).max(80).optional(),
    locale: z.enum(['FR', 'EN']).optional(),
  })
  .refine((body) => Object.keys(body).length > 0, 'au moins un champ attendu');

/** Passage en mode marchand (A2). */
export const MerchantBody = z.object({
  shopName: z.string().trim().min(2).max(80),
  category: z.string().trim().max(60).optional(),
  payoutPhone: CameroonMobile,
  payoutOperator: MobileMoneyOperatorEnum,
  payoutSchedule: z.enum(['DAILY', 'ON_DEMAND']).optional(),
  rccm: z.string().trim().max(40).optional(),
  niu: z.string().trim().max(40).optional(),
});

export const ConsentKindEnum = z.enum(['TERMS', 'PRIVACY', 'LOCATION', 'MARKETING']);

export const ConsentBody = z.object({
  /** Conditions et confidentialité s'acceptent par `POST /v1/me/terms` (signées par code SMS). */
  kind: z.enum(['LOCATION', 'MARKETING']),
  version: z.string().min(1).max(32),
  granted: z.boolean(),
});

export const ConsentDto = z
  .object({
    kind: ConsentKindEnum,
    version: z.string(),
    granted: z.boolean(),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'Consent' });
