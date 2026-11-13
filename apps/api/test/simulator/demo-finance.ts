/**
 * Données fictives pour l'écran Finance du back-office (H5) : ventes encaissées pour quelques
 * boutiques, deux gros reversements à valider, des reversements envoyés, un refusé par
 * l'opérateur, le retrait d'un livreur ; un paiement Mobile Money resté en attente et une
 * opération inconnue chez l'agrégateur, que le contrôle des comptes du jour fait ressortir.
 * Puis le contrôle des comptes des sept derniers jours.
 *
 * Données entièrement fictives, écrites dans la base de DÉVELOPPEMENT :
 *
 *   DATABASE_URL=… REDIS_URL=… pnpm --filter @tara/api demo:finance
 */
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { cameroonDate } from '../../src/common/time.js';
import {
  type AccountSpec,
  merchantPayable,
  PLATFORM_ACCOUNTS,
  riderPayable,
} from '../../src/finance/ledger.accounts.js';
import { LedgerService } from '../../src/finance/ledger.service.js';
import { ReconciliationService } from '../../src/finance/reconciliation.service.js';
import { type FakePaymentProvider, PAYMENT_PROVIDER } from '../../src/payments/payment.provider.js';
import { createTestApp, type SignedIn, signIn, staffUser } from '../helpers/app.js';

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const ctx = await createTestApp();
const http = ctx.http;
const log = (line: string) => process.stdout.write(`${line}\n`);
const ledger = ctx.app.get(LedgerService);
const provider = ctx.app.get<FakePaymentProvider>(PAYMENT_PROVIDER);

/** Écriture fictive passée directement au grand livre, équilibrée. */
async function post(
  kind: 'CASH_DEPOSITED' | 'DELIVERY_COMPLETED',
  description: string,
  postings: { account: AccountSpec; amount: number }[],
): Promise<void> {
  await ctx.prisma.$transaction((tx) =>
    ledger.post(tx, { kind, description, idempotencyKey: `demo:${randomUUID()}`, postings }),
  );
}

interface Shop {
  shopName: string;
  owner: string;
  sales: number;
  payoutPhone: string;
  operator: 'MTN' | 'ORANGE';
}

const SHOPS: Shop[] = [
  {
    shopName: 'Ndolo Mode',
    owner: 'Clarisse Ekambi',
    sales: 412_500,
    payoutPhone: '677214580',
    operator: 'MTN',
  },
  {
    shopName: 'Quincaillerie Bonabéri',
    owner: 'Paul Nkotto',
    sales: 268_000,
    payoutPhone: '699318842',
    operator: 'ORANGE',
  },
  {
    shopName: 'Saveurs de Deïdo',
    owner: 'Brigitte Essomba',
    sales: 86_400,
    payoutPhone: '650447719',
    operator: 'MTN',
  },
  {
    shopName: 'Akwa Phone Center',
    owner: 'Junior Tchinda',
    sales: 54_000,
    payoutPhone: '691205566',
    operator: 'ORANGE',
  },
  // Numéro refusé par l'opérateur : le reversement échoue, l'argent revient sur le solde.
  {
    shopName: 'Bijoux Bonapriso',
    owner: 'Estelle Mbarga',
    sales: 37_500,
    payoutPhone: '655900417',
    operator: 'MTN',
  },
];
const REFUSED = '655900417';

async function openShop(shop: Shop): Promise<{ session: SignedIn; merchantId: string }> {
  const session = await signIn(ctx);
  await ctx.prisma.user.update({ where: { id: session.userId }, data: { fullName: shop.owner } });
  await request(http)
    .put('/v1/me/merchant')
    .set(session.auth)
    .send({ shopName: shop.shopName, payoutPhone: shop.payoutPhone, payoutOperator: shop.operator })
    .expect(200);
  const profile = await ctx.prisma.merchantProfile.update({
    where: { userId: session.userId },
    data: { plan: 'PRO' },
    select: { id: true },
  });
  return { session, merchantId: profile.id };
}

try {
  if ((await ctx.prisma.merchantProfile.count({ where: { shopName: 'Ndolo Mode' } })) > 0) {
    log('Données de finance fictives déjà créées.');
  } else {
    const finance = await staffUser(ctx, ['FINANCE']);
    await ctx.prisma.user.update({
      where: { id: finance.userId },
      data: { fullName: 'Rose Atangana' },
    });
    provider.refusingPhones.add(REFUSED);
    provider.refusingPhones.add(`+237${REFUSED}`);

    // 1. Ventes encaissées à la livraison pour chaque boutique, déposées au bureau.
    const shops: { shop: Shop; session: SignedIn; merchantId: string }[] = [];
    for (const shop of SHOPS) {
      const opened = await openShop(shop);
      await post('CASH_DEPOSITED', `Ventes encaissées pour ${shop.shopName} (démo)`, [
        { account: PLATFORM_ACCOUNTS.officeCash, amount: shop.sales },
        { account: merchantPayable(opened.merchantId), amount: -shop.sales },
      ]);
      shops.push({ shop, ...opened });
    }

    // 2. Livraisons du jour : commission de Tara, gains d'un livreur.
    const rider = await ctx.prisma.riderProfile.findFirstOrThrow({
      where: { status: 'ACTIVE' },
      orderBy: { createdAt: 'asc' },
      select: { id: true, user: { select: { phone: true } } },
    });
    await post('DELIVERY_COMPLETED', 'Livraisons payées en espèces (démo)', [
      { account: PLATFORM_ACCOUNTS.officeCash, amount: 96_000 },
      { account: PLATFORM_ACCOUNTS.commission, amount: -19_200 },
      { account: riderPayable(rider.id), amount: -76_800 },
    ]);

    // 3. Le bureau verse ses espèces sur le compte de l'agrégateur.
    await request(http)
      .post('/v1/admin/finance/treasury-transfers')
      .set(finance.auth)
      .set('Idempotency-Key', randomUUID())
      .send({
        direction: 'OFFICE_TO_MOBILE_MONEY',
        amount: 800_000,
        note: 'Dépôt des espèces du bureau (démo)',
      })
      .expect(201);

    // 4. Chaque boutique demande son reversement : les gros attendent une validation.
    for (const { shop, session } of shops) {
      const asked = await request(http)
        .post('/v1/me/merchant/payouts')
        .set(session.auth)
        .set('Idempotency-Key', randomUUID())
        .expect(201);
      log(`${shop.shopName} : ${shop.sales} F → ${asked.body.status as string}`);
    }

    // 5. Retrait du livreur (sous le seuil de gratuité : frais de retrait).
    const riderSession = await signIn(ctx, rider.user.phone);
    const withdrawal = await request(http)
      .post('/v1/rider/withdrawals')
      .set(riderSession.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount: 25_000, phone: rider.user.phone, operator: 'MTN' })
      .expect(201);
    log(`Retrait livreur : 25 000 F → ${withdrawal.body.status as string}`);

    // 6. Une cliente recharge son solde puis ne valide jamais la demande sur son téléphone.
    const customer = await signIn(ctx);
    await ctx.prisma.user.update({
      where: { id: customer.userId },
      data: { fullName: 'Sandrine Moukoko' },
    });
    const topup = await request(http)
      .post('/v1/me/wallet/topup')
      .set(customer.auth)
      .set('Idempotency-Key', randomUUID())
      .send({ amount: 15_000, phone: customer.phone, operator: 'MTN' })
      .expect(201);
    const paymentId = topup.body.id as string;
    await ctx.prisma.payment.update({
      where: { id: paymentId },
      data: { createdAt: new Date(Date.now() - 3 * HOUR) },
    });

    // 7. Un paiement reçu chez l'agrégateur que Tara ne connaît pas (mauvaise référence).
    const unknown = await provider.collect({
      reference: randomUUID(),
      amount: 7_500,
      phone: '+237677553210',
      operator: 'MTN',
      description: 'Paiement sans référence Tara (démo)',
    });
    await provider.settle(unknown.providerReference, 'SUCCEEDED');
  }

  // Contrôle des comptes des sept derniers jours (aujourd'hui compris).
  const reconciliation = ctx.app.get(ReconciliationService);
  const ranBy = await ctx.prisma.user.findFirst({
    where: { fullName: 'Rose Atangana' },
    select: { id: true },
  });
  for (let back = 6; back >= 0; back -= 1) {
    const day = cameroonDate(new Date(Date.now() - back * DAY));
    const report = await reconciliation.run(day, ranBy?.id ?? null);
    const issues = report.discrepancies as unknown[];
    log(`Contrôle du ${day} : ${report.status} (${issues.length} écart(s))`);
  }
} finally {
  await ctx.app.close();
}
