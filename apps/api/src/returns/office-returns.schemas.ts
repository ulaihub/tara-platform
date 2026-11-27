import { z } from 'zod';

/** Retour sans dette : ce que coûte le retour, ce que le solde paie, ce qui reste à payer. */
export const ReturnQuoteDto = z
  .object({
    /** Frais de retour (plus la course si elle n'était pas payée), 0 une fois réglés. */
    fee: z.int(),
    /** Part prise sur le solde Tara (et les ventes d'une boutique), sans dette. */
    fromBalance: z.int(),
    /** Reste à payer maintenant par Mobile Money (recharge du solde), ou au bureau. */
    toPay: z.int(),
  })
  .meta({ id: 'ReturnQuote' });

/** Colis gardé au bureau Tara, pour l'équipe. */
export const OfficeReturnDto = z
  .object({
    orderId: z.uuid(),
    reference: z.string(),
    senderName: z.string().nullable(),
    senderPhone: z.string(),
    heldSince: z.iso.datetime(),
    until: z.iso.datetime(),
    /** Jours de garde restants (0 : délai dépassé, Tara peut disposer du colis). */
    daysLeft: z.int(),
    /** Frais à payer pour récupérer le colis (0 une fois payés). */
    due: z.int(),
    paidAt: z.iso.datetime().nullable(),
    /** Rappels déjà envoyés à l'expéditeur. */
    reminders: z.int(),
  })
  .meta({ id: 'OfficeReturn' });

export const OfficeHandOverBody = z
  .object({
    /** Code de retrait reçu par SMS après paiement dans l'app. */
    code: z
      .string()
      .regex(/^\d{4}$/)
      .optional(),
    /** Non payé dans l'app : l'équipe a reçu les frais en espèces au bureau. */
    cashReceived: z.boolean().optional(),
    note: z.string().trim().max(300).optional(),
  })
  .refine((body) => Boolean(body.code) !== Boolean(body.cashReceived), {
    message: 'le code de retrait, ou les espèces reçues au bureau',
  });

export const OfficeUnclaimedBody = z.object({
  /** Ce que Tara a fait du colis (don à une association, destruction…). */
  note: z.string().trim().min(3).max(300),
});
