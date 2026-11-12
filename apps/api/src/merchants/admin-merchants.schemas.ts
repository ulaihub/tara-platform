import { z } from 'zod';
import { OrderStatusEnum } from '../orders/orders.schemas.js';

export const AdminMerchantListQuery = z.object({
  /** Nom de la boutique, du gérant, ou numéro de téléphone. */
  q: z.string().trim().max(80).optional(),
  page: z.coerce.number().int().min(1).max(1000).default(1),
});

export const AdminMerchantRowDto = z
  .object({
    id: z.uuid(),
    shopName: z.string(),
    ownerName: z.string().nullable(),
    phone: z.string(),
    category: z.string().nullable(),
    plan: z.enum(['FREE', 'PRO', 'BUSINESS']),
    createdAt: z.iso.datetime(),
    /** Livraisons réussies depuis le début du mois (tarif pro). */
    deliveriesThisMonth: z.int(),
    /** Tarif pro atteint ce mois-ci, en points de base ; 0 sinon. */
    proDiscountBps: z.int(),
    /** Solde dû à la boutique (positif) ou dû par elle (négatif). */
    balance: z.int(),
    lastOrderAt: z.iso.datetime().nullable(),
  })
  .meta({ id: 'AdminMerchantRow' });

export const AdminMerchantPageDto = z
  .object({
    items: z.array(AdminMerchantRowDto),
    total: z.int(),
    page: z.int(),
    pages: z.int(),
    /** Boutiques au tarif pro ce mois-ci. */
    onProRate: z.int(),
  })
  .meta({ id: 'AdminMerchantPage' });

export const AdminMerchantDto = AdminMerchantRowDto.extend({
  payoutPhone: z.string(),
  payoutOperator: z.string(),
  payoutSchedule: z.string(),
  freePayoutFrom: z.int().nullable(),
  rccm: z.string().nullable(),
  niu: z.string().nullable(),
  /** 30 derniers jours : livrées, échouées ou retournées. */
  last30Days: z.object({ delivered: z.int(), failed: z.int(), returned: z.int() }),
  /** Prochain palier du tarif pro, s'il y en a un. */
  nextTier: z.object({ fromDeliveries: z.int(), percentBps: z.int() }).nullable(),
  recentOrders: z.array(
    z.object({
      id: z.uuid(),
      reference: z.string(),
      status: OrderStatusEnum,
      totalPrice: z.int(),
      proDiscountBps: z.int(),
      createdAt: z.iso.datetime(),
    }),
  ),
  recentPayouts: z.array(
    z.object({
      id: z.uuid(),
      amount: z.int(),
      status: z.string(),
      requestedAt: z.iso.datetime(),
    }),
  ),
}).meta({ id: 'AdminMerchant' });
