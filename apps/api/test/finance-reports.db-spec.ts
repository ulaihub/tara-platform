import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import { cameroonDate } from '../src/common/time.js';
import { csvCell } from '../src/finance/journal-export.service.js';
import { PaymentsService } from '../src/payments/payments.service.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import { merchant, placeOrder, setupDouala } from './helpers/orders.js';
import { activeRider } from './helpers/riders.js';

/** Texte d'un PDF par pdftotext s'il est installé (sinon null : la vérification est sautée). */
function pdfText(pdf: Buffer): string | null {
  try {
    const dir = mkdtempSync(join(tmpdir(), 'tara-pdf-'));
    const file = join(dir, 'releve.pdf');
    writeFileSync(file, pdf);
    return execFileSync('pdftotext', ['-layout', file, '-'], { encoding: 'utf8' });
  } catch {
    return null;
  }
}

const binary = (
  res: request.Response,
  callback: (error: Error | null, body: Buffer) => void,
): void => {
  const chunks: Buffer[] = [];
  res.on('data', (chunk: Buffer) => chunks.push(chunk));
  res.on('end', () => callback(null, Buffer.concat(chunks)));
};

describe('Rapprochement, export comptable et relevés (G6, G7, H5)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let ops: SignedIn;
  let finance: SignedIn;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    ops = await staffUser(ctx, ['DISPATCHER']);
    finance = await staffUser(ctx, ['FINANCE']);
    await setupDouala(ctx, admin);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('écrit des cellules CSV sûres pour un tableur', () => {
    expect(csvCell('=HYPERLINK("x")')).toBe(`"'=HYPERLINK(""x"")"`);
    expect(csvCell('-12')).toBe("'-12");
    expect(csvCell(-12)).toBe('-12');
    expect(csvCell('Akwa; rue 3')).toBe('"Akwa; rue 3"');
    expect(csvCell(null)).toBe('');
  });

  it('rapproche une journée sans écart, exporte le journal et édite le relevé', async () => {
    const shop = await merchant(ctx);
    const rider = await activeRider(ctx);
    const placed = await placeOrder(ctx, shop, { codAmount: 8_000 });
    const go = (to: string, extra: Record<string, unknown> = {}) =>
      request(ctx.http)
        .post(`/v1/admin/orders/${placed.id}/transition`)
        .set(ops.auth)
        .send({ to, ...extra })
        .expect(200);
    await go('ASSIGNED', { riderId: rider.riderId });
    await go('PICKED_UP');
    await go('IN_DELIVERY');
    await request(ctx.http)
      .post(`/v1/rider/orders/${placed.id}/collect`)
      .set(rider.auth)
      .send({ method: 'CASH' })
      .expect(200);
    await go('DELIVERED');

    // Les paiements laissés en attente par d'autres scénarios sont tranchés d'abord.
    await ctx.app.get(PaymentsService).refreshPending(new Date(Date.now() + 3_600_000));
    const today = cameroonDate(new Date());
    const report = await request(ctx.http)
      .post(`/v1/admin/finance/reconciliations/${today}/run`)
      .set(finance.auth)
      .expect(200);
    expect(report.body.discrepancies).toEqual([]);
    expect(report.body).toMatchObject({ day: today, status: 'BALANCED' });
    expect(report.body.totals.codCollected).toBeGreaterThanOrEqual(8_000);
    await request(ctx.http)
      .post(`/v1/admin/finance/reconciliations/${today}/run`)
      .set(ops.auth)
      .expect(403);
    const list = await request(ctx.http)
      .get('/v1/admin/finance/reconciliations')
      .set(finance.auth)
      .expect(200);
    expect(list.body[0].day).toBe(today);

    const csv = await request(ctx.http)
      .get(`/v1/admin/finance/journal.csv?from=${today}&to=${today}`)
      .set(finance.auth)
      .expect(200);
    expect(csv.headers['content-type']).toContain('text/csv');
    expect(
      csv.text.startsWith('﻿date;ecriture;nature;libelle;commande;compte;intitule;debit;credit'),
    ).toBe(true);
    expect(csv.text).toContain(placed.reference);
    await request(ctx.http)
      .get(`/v1/admin/finance/journal.csv?from=2026-01-01&to=2026-12-31`)
      .set(finance.auth)
      .expect(400);
    expect(
      await ctx.prisma.auditLog.count({
        where: { actorId: finance.userId, action: 'finance.journal_exported' },
      }),
    ).toBe(1);

    const month = today.slice(0, 7);
    const pdf = await request(ctx.http)
      .get(`/v1/me/merchant/statements/${month}`)
      .set(shop.auth)
      .buffer(true)
      .parse(binary)
      .expect(200);
    expect(pdf.headers['content-type']).toBe('application/pdf');
    const body = pdf.body as Buffer;
    expect(body.subarray(0, 8).toString('latin1')).toBe('%PDF-1.4');
    expect(body.toString('latin1')).toContain('%%EOF');
    const text = pdfText(body);
    if (text !== null) {
      expect(text).toContain('Relevé mensuel');
      expect(text).toContain(placed.reference);
      expect(text).toMatch(/Solde de clôture\s+7 750 FCFA/);
    }
    await request(ctx.http).get('/v1/me/merchant/statements/2099-01').set(shop.auth).expect(400);
    await request(ctx.http).get('/v1/me/merchant/statements/novembre').set(shop.auth).expect(400);
  });

  it('signale les écarts : paiement sans écriture, absent du relevé du prestataire', async () => {
    // Une journée passée, falsifiée : un paiement « réussi » sans aucune écriture.
    const day = '2026-01-15';
    const payment = await ctx.prisma.payment.create({
      data: {
        purpose: 'WALLET_TOPUP',
        method: 'MOMO_MTN',
        amount: 5_000,
        provider: 'fake',
        providerReference: `forged-${randomUUID()}`,
        idempotencyKey: `forged-${randomUUID()}`,
        status: 'SUCCEEDED',
        confirmedAt: new Date(`${day}T10:00:00Z`),
        createdAt: new Date(`${day}T09:59:00Z`),
      },
    });
    const report = await request(ctx.http)
      .post(`/v1/admin/finance/reconciliations/${day}/run`)
      .set(finance.auth)
      .expect(200);
    expect(report.body.status).toBe('DISCREPANCIES');
    const types = (report.body.discrepancies as { type: string; reference: string }[])
      .filter((item) => item.reference === payment.id)
      .map((item) => item.type)
      .sort();
    expect(types).toEqual(['LEDGER_ONLY', 'PAYMENT_NOT_RECORDED']);
  });
});
