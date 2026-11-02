import { Injectable } from '@nestjs/common';
import { AppError } from '../common/errors/app-error.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { cameroonDay } from './reconciliation.service.js';

const DAY = /^\d{4}-\d{2}-\d{2}$/;
/** Export limité à un trimestre par fichier. */
const MAX_DAYS = 92;

/**
 * Une cellule CSV sûre : guillemets doublés, et une valeur commençant par = + - @ est
 * préfixée d'une apostrophe pour qu'un tableur ne l'exécute pas comme une formule.
 */
export function csvCell(value: string | number | null): string {
  if (value === null) return '';
  let text = String(value);
  if (typeof value === 'string' && /^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[";\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** Export comptable du journal (H5) : une ligne par mouvement, débit et crédit séparés. */
@Injectable()
export class JournalExportService {
  constructor(private readonly prisma: PrismaService) {}

  async csv(fromDay: string, toDay: string): Promise<string> {
    if (!DAY.test(fromDay) || !DAY.test(toDay)) {
      throw AppError.badRequest('VALIDATION_FAILED', {}, [
        { path: 'from', message: 'AAAA-MM-JJ attendu' },
      ]);
    }
    const from = cameroonDay(fromDay).from;
    const to = cameroonDay(toDay).to;
    const days = (to.getTime() - from.getTime()) / 86_400_000;
    if (days <= 0 || days > MAX_DAYS) {
      throw AppError.badRequest('VALIDATION_FAILED', {}, [
        { path: 'to', message: `période de 1 à ${MAX_DAYS} jours` },
      ]);
    }
    const postings = await this.prisma.ledgerPosting.findMany({
      where: { entry: { postedAt: { gte: from, lt: to } } },
      include: {
        account: { select: { code: true, name: true } },
        entry: { include: { order: { select: { reference: true } } } },
      },
      orderBy: [{ entryId: 'asc' }, { id: 'asc' }],
    });
    const header = [
      'date',
      'ecriture',
      'nature',
      'libelle',
      'commande',
      'compte',
      'intitule',
      'debit',
      'credit',
    ];
    const rows = postings.map((posting) => [
      posting.entry.postedAt.toISOString(),
      posting.entry.id,
      posting.entry.kind,
      posting.entry.description,
      posting.entry.order?.reference ?? null,
      posting.account.code,
      posting.account.name,
      posting.amount > 0 ? posting.amount : null,
      posting.amount < 0 ? -posting.amount : null,
    ]);
    // Point-virgule et BOM : ouverture directe dans Excel en français.
    return `﻿${[header, ...rows].map((row) => row.map(csvCell).join(';')).join('\r\n')}\r\n`;
  }
}
