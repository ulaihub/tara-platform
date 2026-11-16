import type { Prisma } from '../generated/prisma/client.js';
import type { UserRole } from '../generated/prisma/enums.js';

/**
 * Ajoute un rôle au compte sans toucher aux autres, en une seule écriture. Les rôles d'une
 * session (`AuthUser.roles`) sont filtrés : ceux de l'équipe n'y figurent qu'avec un second
 * facteur récent. Ils ne doivent donc jamais servir à réécrire les rôles du compte, sous
 * peine d'effacer le rôle d'un membre de l'équipe qui ouvre une boutique ou livre.
 */
export async function addRole(
  tx: Prisma.TransactionClient,
  userId: string,
  role: UserRole,
): Promise<void> {
  await tx.user.updateMany({
    where: { id: userId, NOT: { roles: { has: role } } },
    data: { roles: { push: role } },
  });
}
