import { z } from 'zod';

/** Message tapé par l'expéditeur ou le livreur (« J'arrive », « Je suis devant le portail »). */
export const SendMessageBody = z.object({
  body: z.string().trim().min(1).max(500),
});

export const OrderMessageDto = z
  .object({
    id: z.uuid(),
    /** Écrit par la personne qui lit la conversation. */
    mine: z.boolean(),
    authorRole: z.enum(['SENDER', 'RIDER']),
    body: z.string(),
    createdAt: z.iso.datetime(),
    /** Lu par l'autre personne ; null tant qu'il ne l'a pas ouvert. */
    readAt: z.iso.datetime().nullable(),
  })
  .meta({ id: 'OrderMessage' });

export const OrderConversationDto = z
  .object({
    /** Nouveaux messages possibles : un livreur est sur la commande et elle est en cours. */
    open: z.boolean(),
    messages: z.array(OrderMessageDto),
  })
  .meta({ id: 'OrderConversation' });
