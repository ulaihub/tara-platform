import { Injectable } from '@nestjs/common';
import { AppError } from '../common/errors/app-error.js';
import { cameroonDate } from '../common/time.js';
import type { JournalEntryKind } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { merchantPayable, naturalBalance } from './ledger.accounts.js';
import { PdfDocument } from './pdf.js';

const MONTH = /^(\d{4})-(0[1-9]|1[0-2])$/;

const money = (value: number): string =>
  `${new Intl.NumberFormat('fr-FR').format(value).replace(/\s/g, ' ')} FCFA`;

const signed = (value: number): string => (value > 0 ? `+${money(value)}` : money(value));

/** Libellés des lignes du relevé, du point de vue du marchand. */
const KIND_LABELS: Partial<Record<JournalEntryKind, string>> = {
  COD_COLLECTED: 'Encaissements (net des frais)',
  ORDER_CHARGED: 'Frais de livraison payés par le solde',
  ORDER_RELEASED: 'Frais rendus (commandes annulées)',
  FAILURE_FEE_CHARGED: 'Frais de nouvelle tentative et de retour',
  CREDIT_GRANTED: 'Avoirs',
  PAYMENT_RECEIVED: 'Recharges et paiements',
  PAYOUT_REQUESTED: 'Reversements',
  PAYOUT_FAILED: 'Reversements échoués, montants rendus',
};

/** Début du mois `month` (AAAA-MM) et du mois suivant, à l'heure du Cameroun (UTC+1). */
export function monthBounds(month: string): { from: Date; to: Date } {
  const match = MONTH.exec(month);
  if (!match) throw AppError.badRequest('STATEMENT_PERIOD_INVALID');
  const year = Number(match[1]);
  const index = Number(match[2]) - 1;
  const from = new Date(Date.UTC(year, index, 1) - 3_600_000);
  const to = new Date(Date.UTC(year, index + 1, 1) - 3_600_000);
  return { from, to };
}

/**
 * Relevé mensuel PDF d'un marchand (G7) : solde d'ouverture, synthèse par nature, toutes
 * les lignes du mois avec le solde courant, solde de clôture. Construit depuis le grand
 * livre : il concorde toujours avec le portefeuille affiché dans l'app.
 */
@Injectable()
export class StatementsService {
  constructor(private readonly prisma: PrismaService) {}

  async merchantStatement(
    merchantId: string,
    month: string,
    now = new Date(),
  ): Promise<{ filename: string; pdf: Buffer }> {
    const { from, to } = monthBounds(month);
    if (from > now) throw AppError.badRequest('STATEMENT_PERIOD_INVALID');
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { id: merchantId } });
    if (!merchant) throw AppError.notFound();
    const account = await this.prisma.ledgerAccount.findUnique({
      where: { code: merchantPayable(merchantId).code },
    });

    let opening = 0;
    let lines: {
      at: Date;
      reference: string | null;
      description: string;
      kind: JournalEntryKind;
      amount: number;
    }[] = [];
    if (account) {
      const [before] = await this.prisma.$queryRaw<{ total: bigint | null }[]>`
        SELECT SUM(p.amount)::bigint AS total
          FROM ledger_postings p JOIN journal_entries e ON e.id = p.entry_id
         WHERE p.account_id = ${account.id}::uuid AND e.posted_at < ${from}`;
      opening = naturalBalance(account.type, Number(before?.total ?? 0));
      const postings = await this.prisma.ledgerPosting.findMany({
        where: { accountId: account.id, entry: { postedAt: { gte: from, lt: to } } },
        include: { entry: { include: { order: { select: { reference: true } } } } },
        orderBy: { id: 'asc' },
      });
      lines = postings.map((posting) => ({
        at: posting.entry.postedAt,
        reference: posting.entry.order?.reference ?? null,
        description: posting.entry.description,
        kind: posting.entry.kind,
        amount: naturalBalance(account.type, posting.amount),
      }));
    }
    const collections = await this.prisma.codCollection.aggregate({
      where: { order: { merchantId }, collectedAt: { gte: from, lt: to } },
      _sum: { collectedAmount: true, feeAmount: true },
      _count: true,
    });
    const closing = lines.reduce((balance, line) => balance + line.amount, opening);

    const pdf = new PdfDocument();
    const left = 40;
    const right = pdf.width - 40;
    let y = 50;
    const header = (): void => {
      pdf.text(left, y, 'Tara · Relevé mensuel du portefeuille marchand', { size: 14, bold: true });
      y += 18;
      pdf.text(
        left,
        y,
        `${merchant.shopName}${merchant.rccm ? ` · RCCM ${merchant.rccm}` : ''}${merchant.niu ? ` · NIU ${merchant.niu}` : ''}`,
        { size: 10 },
      );
      pdf.text(right, y, `Période : ${month}`, { size: 10, alignRight: true });
      y += 14;
      pdf.text(left, y, `Édité le ${cameroonDate(now)} · montants en francs CFA (XAF)`, {
        size: 8,
        gray: true,
      });
      y += 10;
      pdf.line(left, y, right, y);
      y += 18;
    };
    header();

    // Synthèse.
    pdf.text(left, y, 'Synthèse', { size: 11, bold: true });
    y += 16;
    const summary: [string, string][] = [['Solde d’ouverture', money(opening)]];
    const byKind = new Map<JournalEntryKind, number>();
    for (const line of lines) byKind.set(line.kind, (byKind.get(line.kind) ?? 0) + line.amount);
    for (const [kind, total] of byKind) summary.push([KIND_LABELS[kind] ?? kind, signed(total)]);
    summary.push(
      [
        `Contre-remboursements encaissés (${collections._count})`,
        money(collections._sum.collectedAmount ?? 0),
      ],
      [
        'dont frais d’encaissement Tara (2 %, min. 250 FCFA)',
        money(collections._sum.feeAmount ?? 0),
      ],
    );
    for (const [label, value] of summary) {
      pdf.text(left, y, label, { size: 9 });
      pdf.text(right, y, value, { size: 9, alignRight: true });
      y += 13;
    }
    pdf.line(left, y - 4, right, y - 4);
    y += 8;
    pdf.text(left, y, 'Solde de clôture', { size: 10, bold: true });
    pdf.text(right, y, money(closing), { size: 10, bold: true, alignRight: true });
    y += 26;

    // Détail.
    const columns = {
      date: left,
      reference: left + 62,
      label: left + 140,
      amount: right - 85,
      balance: right,
    };
    const tableHeader = (): void => {
      pdf.text(columns.date, y, 'Date', { size: 8, bold: true });
      pdf.text(columns.reference, y, 'Commande', { size: 8, bold: true });
      pdf.text(columns.label, y, 'Libellé', { size: 8, bold: true });
      pdf.text(columns.amount, y, 'Montant', { size: 8, bold: true, alignRight: true });
      pdf.text(columns.balance, y, 'Solde', { size: 8, bold: true, alignRight: true });
      y += 6;
      pdf.line(left, y, right, y);
      y += 12;
    };
    pdf.text(left, y, `Détail (${lines.length} ligne${lines.length > 1 ? 's' : ''})`, {
      size: 11,
      bold: true,
    });
    y += 16;
    tableHeader();
    let balance = opening;
    for (const line of lines) {
      if (y > pdf.height - 50) {
        pdf.addPage();
        y = 50;
        header();
        tableHeader();
      }
      balance += line.amount;
      const date = cameroonDate(line.at).split('-').reverse().join('/');
      const label =
        line.description.length > 52 ? `${line.description.slice(0, 51)}…` : line.description;
      pdf.text(columns.date, y, date, { size: 8 });
      pdf.text(columns.reference, y, line.reference ?? '—', { size: 8 });
      pdf.text(columns.label, y, label, { size: 8 });
      pdf.text(columns.amount, y, signed(line.amount), { size: 8, alignRight: true });
      pdf.text(columns.balance, y, money(balance), { size: 8, alignRight: true });
      y += 12;
    }
    if (lines.length === 0)
      pdf.text(left, y, 'Aucun mouvement ce mois-ci.', { size: 9, gray: true });

    const filename = `tara-releve-${month}-${merchant.shopName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .slice(0, 40)}.pdf`;
    return { filename, pdf: pdf.render() };
  }
}
