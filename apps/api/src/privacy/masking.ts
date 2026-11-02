import type { Prisma } from '../generated/prisma/client.js';
import type { PrismaService } from '../prisma/prisma.service.js';

type Client = PrismaService | Prisma.TransactionClient;

/**
 * Masque les coordonnées des destinataires d'une sélection de commandes : il reste les deux
 * derniers chiffres du numéro et l'initiale du nom, assez pour un litige, plus rien pour
 * démarcher la personne. Les instructions et la note du destinataire, texte libre pouvant
 * contenir des données personnelles, sont effacées.
 */
export async function maskOrdersWhere(client: Client, where: Prisma.Sql): Promise<number> {
  return client.$executeRaw`
    UPDATE orders
       SET recipient_phone = left(recipient_phone, 5) || '•••••' || right(recipient_phone, 2),
           recipient_name = left(recipient_name, 1) || '.',
           recipient_note = NULL,
           instructions = NULL,
           pii_masked_at = now()
     WHERE pii_masked_at IS NULL AND ${where}`;
}
