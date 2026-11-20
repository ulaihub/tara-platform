import { z } from 'zod';
import { OrderStatusEnum } from '../orders/orders.schemas.js';

/**
 * Reçu vu par n'importe qui qui en a le code signé (QR du reçu imprimé) : seulement ce qui
 * est déjà écrit sur le papier, pour que l'on puisse comparer. Aucun numéro de téléphone.
 */
export const PublicReceiptDto = z
  .object({
    reference: z.string(),
    status: OrderStatusEnum,
    /** Date d'émission : création de la commande. */
    issuedAt: z.iso.datetime(),
    senderName: z.string().nullable(),
    /** Prénom et initiale du destinataire. */
    recipientName: z.string(),
    dropoffNeighborhood: z.string().nullable(),
    /** Prix de la course et s'il est réglé. */
    fee: z.int(),
    feePaid: z.boolean(),
    deliveredAt: z.iso.datetime().nullable(),
    /** Somme encaissée à la porte pour le compte de l'expéditeur ; null si aucune. */
    collectedForSender: z.int().nullable(),
  })
  .meta({ id: 'PublicReceipt' });
