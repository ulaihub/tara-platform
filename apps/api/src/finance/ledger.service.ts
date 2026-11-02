import { Injectable } from '@nestjs/common';
import { uuidv7 } from '../common/crypto.js';
import type { Prisma } from '../generated/prisma/client.js';
import type { JournalEntryKind } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { type AccountSpec, naturalBalance } from './ledger.accounts.js';

type Db = Prisma.TransactionClient | PrismaService;

export interface PostingInput {
  account: AccountSpec;
  /** FCFA entiers : positif = débit, négatif = crédit. Les lignes à 0 sont ignorées. */
  amount: number;
}

export interface EntryInput {
  kind: JournalEntryKind;
  description: string;
  /** Clé unique : la même écriture ne peut jamais être passée deux fois. */
  idempotencyKey: string;
  orderId?: string | null;
  paymentId?: string | null;
  payoutId?: string | null;
  postedById?: string | null;
  postings: PostingInput[];
}

export class UnbalancedEntryError extends Error {}

/** Lignes non nulles, regroupées par compte ; refuse une écriture déséquilibrée. */
export function normalizePostings(postings: PostingInput[]): PostingInput[] {
  const byCode = new Map<string, PostingInput>();
  for (const posting of postings) {
    if (!Number.isInteger(posting.amount)) {
      throw new UnbalancedEntryError(`Montant non entier sur ${posting.account.code}`);
    }
    const current = byCode.get(posting.account.code);
    byCode.set(posting.account.code, {
      account: posting.account,
      amount: (current?.amount ?? 0) + posting.amount,
    });
  }
  const lines = [...byCode.values()].filter((posting) => posting.amount !== 0);
  const sum = lines.reduce((total, posting) => total + posting.amount, 0);
  if (sum !== 0) throw new UnbalancedEntryError(`Écriture déséquilibrée de ${sum} FCFA`);
  if (lines.length < 2) throw new UnbalancedEntryError('Une écriture compte au moins deux lignes');
  return lines;
}

/**
 * Grand livre en partie double (voir ARCHITECTURE.md). Les écritures sont en ajout seul et
 * contrôlées deux fois : ici avant l'envoi, puis par un trigger PostgreSQL à la validation.
 * Les soldes ne sont jamais stockés : ils se calculent à partir des lignes.
 */
@Injectable()
export class LedgerService {
  constructor(private readonly prisma: PrismaService) {}

  /** Identifiant du compte, créé au premier usage (sans risque en cas d'appels simultanés). */
  async accountId(db: Db, spec: AccountSpec): Promise<string> {
    await db.$executeRaw`
      INSERT INTO ledger_accounts (id, code, name, type, owner_type, owner_id)
      VALUES (${uuidv7()}::uuid, ${spec.code}, ${spec.name}, ${spec.type}::ledger_account_type,
              ${spec.ownerType}::ledger_owner_type, ${spec.ownerId ?? null}::uuid)
      ON CONFLICT (code) DO NOTHING`;
    const account = await db.ledgerAccount.findUniqueOrThrow({ where: { code: spec.code } });
    return account.id;
  }

  /**
   * Passe une écriture dans la transaction donnée. Si la clé a déjà servi, rien n'est
   * écrit et l'écriture existante est renvoyée (rejeu d'un webhook, tâche relancée).
   */
  async post(
    tx: Prisma.TransactionClient,
    entry: EntryInput,
  ): Promise<{ entryId: string; created: boolean }> {
    const existing = await tx.journalEntry.findUnique({
      where: { idempotencyKey: entry.idempotencyKey },
    });
    if (existing) return { entryId: existing.id, created: false };
    const lines = normalizePostings(entry.postings);
    // Une requête à la fois dans une transaction (une seule connexion).
    const accountIds: string[] = [];
    for (const line of lines) accountIds.push(await this.accountId(tx, line.account));
    const created = await tx.journalEntry.create({
      data: {
        kind: entry.kind,
        description: entry.description,
        idempotencyKey: entry.idempotencyKey,
        orderId: entry.orderId ?? null,
        paymentId: entry.paymentId ?? null,
        payoutId: entry.payoutId ?? null,
        postedById: entry.postedById ?? null,
        postings: {
          create: lines.map((line, index) => ({
            accountId: accountIds[index] ?? '',
            amount: line.amount,
          })),
        },
      },
    });
    return { entryId: created.id, created: true };
  }

  /**
   * Verrouille des comptes jusqu'à la fin de la transaction, dans un ordre fixe (pas
   * d'interblocage) : deux débits simultanés ne peuvent pas dépenser le même solde.
   */
  async lock(tx: Prisma.TransactionClient, specs: AccountSpec[]): Promise<void> {
    const ids: string[] = [];
    for (const spec of specs) ids.push(await this.accountId(tx, spec));
    for (const id of [...new Set(ids)].sort()) {
      await tx.$executeRaw`SELECT id FROM ledger_accounts WHERE id = ${id}::uuid FOR UPDATE`;
    }
  }

  /** Solde naturel d'un compte (0 s'il n'existe pas encore). */
  async balance(spec: AccountSpec, db: Db = this.prisma): Promise<number> {
    return (await this.balances([spec], db)).get(spec.code) ?? 0;
  }

  async balances(specs: AccountSpec[], db: Db = this.prisma): Promise<Map<string, number>> {
    const result = new Map<string, number>(specs.map((spec) => [spec.code, 0]));
    if (specs.length === 0) return result;
    const rows = await db.$queryRaw<
      { code: string; type: AccountSpec['type']; total: bigint | null }[]
    >`
      SELECT a.code, a.type, SUM(p.amount)::bigint AS total
        FROM ledger_accounts a
        LEFT JOIN ledger_postings p ON p.account_id = a.id
       WHERE a.code = ANY(${specs.map((spec) => spec.code)}::text[])
       GROUP BY a.code, a.type`;
    for (const row of rows) result.set(row.code, naturalBalance(row.type, Number(row.total ?? 0)));
    return result;
  }
}
