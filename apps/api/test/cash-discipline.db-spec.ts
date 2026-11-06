import request from 'supertest';
import { CashDisciplineService } from '../src/finance/cash-discipline.service.js';
import { PLATFORM_ACCOUNTS, riderCashHeld, riderPayable } from '../src/finance/ledger.accounts.js';
import { LedgerService } from '../src/finance/ledger.service.js';
import { type FakePushProvider, PUSH_PROVIDER } from '../src/notifications/push.provider.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import { nearAkwa } from './helpers/orders.js';
import { activeRider, type TestRider } from './helpers/riders.js';

const OPS_PHONE = '+237690000003';
const HOUR = 3_600_000;

describe('Espèces d’avant le solde prépayé : dépôt sous 24 h (G5)', () => {
  let ctx: TestContext;
  let finance: SignedIn;
  let cash: CashDisciplineService;
  let ledger: LedgerService;
  let push: FakePushProvider;

  beforeAll(async () => {
    ctx = await createTestApp({ OPS_ALERT_PHONES: OPS_PHONE });
    finance = await staffUser(ctx, ['FINANCE']);
    cash = ctx.app.get(CashDisciplineService);
    ledger = ctx.app.get(LedgerService);
    push = ctx.app.get<FakePushProvider>(PUSH_PROVIDER);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  /** Espèces encaissées (contre-remboursement) et gains dus, passés au grand livre. */
  const collect = (rider: TestRider, amount: number, key: string) =>
    ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'COD_COLLECTED',
        description: 'Encaissement (test)',
        idempotencyKey: `test-cash:${rider.riderId}:${key}`,
        postings: [
          { account: riderCashHeld(rider.riderId), amount },
          { account: PLATFORM_ACCOUNTS.codFees, amount: -amount },
        ],
      }),
    );
  const earn = (rider: TestRider, amount: number) =>
    ctx.prisma.$transaction((tx) =>
      ledger.post(tx, {
        kind: 'DELIVERY_COMPLETED',
        description: 'Gains (test)',
        idempotencyKey: `test-earn:${rider.riderId}`,
        postings: [
          { account: riderPayable(rider.riderId), amount: -amount },
          { account: PLATFORM_ACCOUNTS.commission, amount },
        ],
      }),
    );
  const deposit = (rider: TestRider, amount: number, key: string) =>
    request(ctx.http)
      .post(`/v1/admin/finance/riders/${rider.riderId}/cash-deposits`)
      .set(finance.auth)
      .set('Idempotency-Key', key)
      .send({ amount, note: 'Dépôt au bureau' })
      .expect(201);
  const goOnline = (rider: TestRider) =>
    request(ctx.http)
      .put('/v1/rider/presence')
      .set(rider.auth)
      .send({ online: true, ...nearAkwa(0) });

  it('échéance à 24 h, rappel, retard qui bloque, suspension avec gains retenus et garant', async () => {
    const rider = await activeRider(ctx, { balance: 0 });
    const start = Date.now();
    await collect(rider, 10_000, 'a');
    await earn(rider, 3_000);

    const wallet = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    expect(wallet.body.cashOverdue).toBe(false);
    const dueBy = Date.parse(wallet.body.cashDueBy);
    expect(Math.abs(dueBy - (start + 24 * HOUR))).toBeLessThan(60_000);

    // Rappel de 18 h : espèces à déposer avant l'heure limite.
    await cash.remind(new Date(start + HOUR), [rider.riderId]);
    expect(push.lastTo(rider.pushToken)).toMatchObject({ data: { type: 'cash.reminder' } });

    // Avant l'échéance : rien ne change.
    await cash.sweep(new Date(start + 23 * HOUR), [rider.riderId]);
    expect(
      (await ctx.prisma.riderProfile.findUniqueOrThrow({ where: { id: rider.riderId } }))
        .cashOverdueSince,
    ).toBeNull();

    // Échéance dépassée : plus de courses jusqu'au dépôt.
    await cash.sweep(new Date(start + 25 * HOUR), [rider.riderId]);
    const late = await ctx.prisma.riderProfile.findUniqueOrThrow({ where: { id: rider.riderId } });
    expect(late.cashOverdueSince).not.toBeNull();
    expect(push.lastTo(rider.pushToken)).toMatchObject({ data: { type: 'cash.overdue' } });
    const blocked = await goOnline(rider).expect(422);
    expect(blocked.body.error.code).toBe('RIDER_NOT_ELIGIBLE');
    expect(JSON.stringify(blocked.body)).toContain('CASH_OVERDUE');

    // Dépôt partiel : les espèces les plus anciennes restent dues, toujours en retard.
    await deposit(rider, 4_000, 'dep-partiel-0001');
    await cash.sweep(new Date(start + 26 * HOUR), [rider.riderId]);
    expect(
      (await ctx.prisma.riderProfile.findUniqueOrThrow({ where: { id: rider.riderId } }))
        .cashOverdueSince,
    ).not.toBeNull();

    // 72 h de retard : suspension, gains retenus sur la dette, équipe prévenue avec le garant.
    await cash.sweep(new Date(start + (24 + 72 + 1) * HOUR), [rider.riderId]);
    const suspended = await ctx.prisma.riderProfile.findUniqueOrThrow({
      where: { id: rider.riderId },
    });
    expect(suspended.status).toBe('SUSPENDED');
    expect(await ledger.balance(riderPayable(rider.riderId))).toBe(0);
    expect(await ledger.balance(riderCashHeld(rider.riderId))).toBe(3_000);
    const sms = ctx.sms.lastTo(OPS_PHONE)?.text ?? '';
    expect(sms).toContain('3000 FCFA retenus');
    expect(sms).toContain('Garant Test (+237699000111)');
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { entityId: rider.riderId, action: 'rider.cash_suspended' },
    });
    expect(audit).not.toBeNull();
    // Passage suivant : pas de seconde retenue ni de second SMS.
    const smsCount = ctx.sms.outbox.length;
    await cash.sweep(new Date(start + (24 + 73) * HOUR), [rider.riderId]);
    expect(ctx.sms.outbox.length).toBe(smsCount);

    // Tout déposé : le retard tombe ; la suspension reste à lever par la finance.
    await deposit(rider, 3_000, 'dep-solde-0001');
    await cash.sweep(new Date(start + 100 * HOUR), [rider.riderId]);
    const settled = await ctx.prisma.riderProfile.findUniqueOrThrow({
      where: { id: rider.riderId },
    });
    expect(settled.cashOverdueSince).toBeNull();
    expect(settled.status).toBe('SUSPENDED');
    const after = await request(ctx.http).get('/v1/rider/wallet').set(rider.auth).expect(200);
    expect(after.body).toMatchObject({ cashHeld: 0, cashDueBy: null, cashOverdue: false });
  });

  it('dépôt dans les temps : aucun retard', async () => {
    const rider = await activeRider(ctx, { balance: 0 });
    const start = Date.now();
    await collect(rider, 5_000, 'b');
    await deposit(rider, 5_000, 'dep-temps-0001');
    await cash.sweep(new Date(start + 30 * HOUR), [rider.riderId]);
    const profile = await ctx.prisma.riderProfile.findUniqueOrThrow({
      where: { id: rider.riderId },
    });
    expect(profile.cashOverdueSince).toBeNull();
  });
});
