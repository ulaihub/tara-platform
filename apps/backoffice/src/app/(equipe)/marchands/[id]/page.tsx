import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Badge } from '@/components/ui';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { longDate } from '@/lib/douala';
import { dateTime, money } from '@/lib/format';
import { percent, PRICING_ROLES } from '@/lib/merchants';
import { statusLabel } from '@/lib/orders';
import { displayPhone } from '@/lib/phone';
import type { AdminMerchant } from '@/lib/schemas';

export const metadata: Metadata = { title: 'Boutique' };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Fiche d'une boutique (H4) : activité, tarif pro, argent, dernières commandes. */
export default async function MerchantPage({ params }: { params: Promise<{ id: string }> }) {
  await requireStaff(PRICING_ROLES);
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  let shop: AdminMerchant;
  try {
    shop = await staffApi<AdminMerchant>(`/admin/merchants/${id}`);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  const toNext = shop.nextTier ? shop.nextTier.fromDeliveries - shop.deliveriesThisMonth : 0;

  return (
    <div className="mx-auto max-w-[1100px]">
      <Link href="/marchands" className="text-[14px] font-bold text-accent hover:underline">
        ← Boutiques
      </Link>
      <header className="mt-3 mb-6 flex flex-wrap items-start gap-3">
        <div className="flex-1">
          <h1 className="font-display text-[28px] font-bold tracking-tight">{shop.shopName}</h1>
          <p className="text-muted">
            {shop.ownerName ?? 'Gérant sans nom'} · {displayPhone(shop.phone)}
            {shop.category ? ` · ${shop.category}` : ''} · cliente depuis le{' '}
            {longDate.format(new Date(shop.createdAt))}
          </p>
        </div>
        {shop.proDiscountBps > 0 ? (
          <Badge tone="ok">Tarif pro −{percent(shop.proDiscountBps)}</Badge>
        ) : (
          <Badge>Tarif normal</Badge>
        )}
      </header>

      <div className="mb-5 grid gap-4 md:grid-cols-3">
        <div className="rounded-3xl border border-line bg-panel p-5 shadow-card">
          <p className="text-[13px] font-bold text-muted">Livraisons réussies ce mois-ci</p>
          <p className="mt-2 font-display text-[28px] font-bold tabular-nums">
            {shop.deliveriesThisMonth}
          </p>
          <p className="mt-1 text-[13px] text-muted">
            {shop.nextTier
              ? `Encore ${toNext} pour passer à −${percent(shop.nextTier.percentBps)}.`
              : shop.proDiscountBps > 0
                ? 'Palier le plus haut atteint.'
                : 'Pas de tarif pro configuré.'}
          </p>
        </div>
        <div className="rounded-3xl border border-line bg-panel p-5 shadow-card">
          <p className="text-[13px] font-bold text-muted">30 derniers jours</p>
          <p className="mt-2 font-display text-[28px] font-bold tabular-nums">
            {shop.last30Days.delivered}
          </p>
          <p className="mt-1 text-[13px] text-muted">
            livrées · {shop.last30Days.failed} échec{shop.last30Days.failed > 1 ? 's' : ''} ·{' '}
            {shop.last30Days.returned} retour{shop.last30Days.returned > 1 ? 's' : ''}
          </p>
        </div>
        <div className="rounded-3xl border border-line bg-panel p-5 shadow-card">
          <p className="text-[13px] font-bold text-muted">Solde de la boutique</p>
          <p
            className={`mt-2 font-display text-[28px] font-bold tabular-nums ${shop.balance < 0 ? 'text-danger' : ''}`}
          >
            {money(shop.balance)}
          </p>
          <p className="mt-1 text-[13px] text-muted">
            Reversé au {displayPhone(shop.payoutPhone)} ({shop.payoutOperator})
            {shop.freePayoutFrom !== null
              ? ` · retrait gratuit dès ${money(shop.freePayoutFrom)}`
              : ''}
          </p>
        </div>
      </div>

      <div className="grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="overflow-hidden rounded-3xl border border-line bg-panel shadow-card">
          <h2 className="px-5 pt-5 font-display text-[17px] font-bold">Dernières commandes</h2>
          {shop.recentOrders.length === 0 ? (
            <p className="px-5 py-5 text-muted">Aucune commande.</p>
          ) : (
            <div className="relative overflow-x-auto">
              <table className="min-w-[560px] mt-3 w-full text-left text-[14px]">
                <tbody>
                  {shop.recentOrders.map((order) => (
                    <tr key={order.id} className="border-t border-line">
                      <td className="px-5 py-2.5">
                        <Link
                          href={`/commandes/${order.id}`}
                          className="font-mono font-bold text-accent hover:underline"
                        >
                          {order.reference}
                        </Link>
                        <span className="block text-[12px] text-muted">
                          {dateTime(order.createdAt)}
                        </span>
                      </td>
                      <td className="px-5 py-2.5 text-muted">{statusLabel(order.status, null)}</td>
                      <td className="px-5 py-2.5 text-right font-bold tabular-nums">
                        {money(order.totalPrice)}
                        {order.proDiscountBps > 0 ? (
                          <span className="block text-[12px] font-normal text-ok">
                            tarif pro −{percent(order.proDiscountBps)}
                          </span>
                        ) : null}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
        <section className="rounded-3xl border border-line bg-panel p-5 shadow-card">
          <h2 className="mb-3 font-display text-[17px] font-bold">Derniers reversements</h2>
          {shop.recentPayouts.length === 0 ? (
            <p className="text-muted">Aucun reversement.</p>
          ) : (
            <ul className="divide-y divide-line">
              {shop.recentPayouts.map((payout) => (
                <li key={payout.id} className="flex items-baseline gap-3 py-2">
                  <span className="flex-1 text-[13px] text-muted">
                    {dateTime(payout.requestedAt)}
                  </span>
                  <span className="font-bold tabular-nums">{money(payout.amount)}</span>
                </li>
              ))}
            </ul>
          )}
          <Link
            href="/finance/reversements?vue=all"
            className="mt-3 inline-block text-[13px] font-bold text-accent hover:underline"
          >
            Tous les reversements →
          </Link>
          {shop.rccm || shop.niu ? (
            <p className="mt-4 text-[12px] text-faint">
              {shop.rccm ? `RCCM ${shop.rccm}` : ''}
              {shop.rccm && shop.niu ? ' · ' : ''}
              {shop.niu ? `NIU ${shop.niu}` : ''}
            </p>
          ) : null}
        </section>
      </div>
    </div>
  );
}
