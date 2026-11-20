import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { Badge, cx } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime, money } from '@/lib/format';
import { percent, PRICING_ROLES } from '@/lib/merchants';
import { displayPhone } from '@/lib/phone';
import type { AdminMerchantPage, PricingSettings } from '@/lib/schemas';
import { MerchantsHeader } from './tabs';

export const metadata: Metadata = { title: 'Boutiques' };

type Search = { q?: string; page?: string };

function hrefWith(current: Search, changes: Partial<Search>): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries({ ...current, ...changes })) {
    if (value) params.set(key, value);
  }
  const query = params.toString();
  return query ? `/marchands?${query}` : '/marchands';
}

/**
 * Boutiques (H4) : les plus actives du mois d'abord, avec le tarif pro atteint, le solde et
 * la dernière commande. Une boutique ouvre sa fiche.
 */
export default async function MerchantsPage({ searchParams }: { searchParams: Promise<Search> }) {
  await requireStaff(PRICING_ROLES);
  const search = await searchParams;
  const q = search.q?.trim().slice(0, 80) || undefined;
  const page = Math.max(1, Number(search.page) || 1);
  const [list, settings] = await Promise.all([
    staffApi<AdminMerchantPage>('/admin/merchants', { query: { q, page } }),
    staffApi<PricingSettings>('/admin/pricing-settings/Douala'),
  ]);
  const firstTier = settings.volumeDiscounts[0];

  return (
    <div className="mx-auto max-w-[1280px]">
      <MerchantsHeader
        current="/marchands"
        aside={`${list.total} boutique${list.total > 1 ? 's' : ''} · ${list.onProRate} au tarif pro ce mois-ci`}
      />

      <form action="/marchands" className="mb-4 flex max-w-xl gap-2">
        <label className="relative flex-1">
          <span className="sr-only">Rechercher une boutique</span>
          <span className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-faint">
            <Icon name="search" size={16} />
          </span>
          <input
            name="q"
            defaultValue={q}
            placeholder="Boutique, gérant ou numéro"
            className="block w-full rounded-2xl border border-line bg-panel py-2.5 pr-3 pl-9 text-[14px] focus:border-accent-line focus:outline-none"
          />
        </label>
        <button
          type="submit"
          className="min-h-10 rounded-2xl bg-text px-4 text-[14px] font-bold text-bg"
        >
          Rechercher
        </button>
      </form>

      {firstTier ? (
        <p className="mb-3 text-[13px] text-muted">
          Tarif pro : −{percent(firstTier.percentBps)} dès {firstTier.fromDeliveries} livraisons
          réussies dans le mois
          {settings.volumeDiscounts
            .slice(1)
            .map((tier) => `, −${percent(tier.percentBps)} dès ${tier.fromDeliveries}`)
            .join('')}
          .{' '}
          <Link href="/marchands/tarifs" className="font-bold text-accent hover:underline">
            Modifier
          </Link>
        </p>
      ) : null}

      {list.items.length === 0 ? (
        <div className="bo-glass rounded-[22px] px-6 py-16 text-center">
          <p className="font-display text-[18px] font-bold">Aucune boutique</p>
          <p className="mt-1 text-muted">
            {q ? 'Aucun résultat pour cette recherche.' : 'Les boutiques apparaîtront ici.'}
          </p>
        </div>
      ) : (
        <div className="relative overflow-x-auto bo-glass rounded-[22px] shadow-card">
          <table className="w-full min-w-[640px] text-left text-[14px]">
            <thead className="border-b border-line text-[12px] font-bold text-faint uppercase">
              <tr>
                <th className="px-4 py-3">Boutique</th>
                <th className="px-4 py-3">Gérant</th>
                <th className="px-4 py-3 text-right">Livraisons du mois</th>
                <th className="px-4 py-3">Tarif</th>
                <th className="px-4 py-3 text-right">Solde</th>
                <th className="px-4 py-3">Dernière commande</th>
              </tr>
            </thead>
            <tbody>
              {list.items.map((shop) => (
                <tr key={shop.id} className="border-b border-line last:border-0">
                  <td className="px-4 py-3">
                    <Link
                      href={`/marchands/${shop.id}`}
                      className="font-bold text-accent hover:underline"
                    >
                      {shop.shopName}
                    </Link>
                    {shop.category ? (
                      <span className="block text-[12px] text-muted">{shop.category}</span>
                    ) : null}
                  </td>
                  <td className="px-4 py-3">
                    {shop.ownerName ?? '—'}
                    <span className="block text-[12px] text-muted">{displayPhone(shop.phone)}</span>
                  </td>
                  <td className="px-4 py-3 text-right font-bold tabular-nums">
                    {shop.deliveriesThisMonth}
                  </td>
                  <td className="px-4 py-3">
                    {shop.proDiscountBps > 0 ? (
                      <Badge tone="ok">Pro −{percent(shop.proDiscountBps)}</Badge>
                    ) : (
                      <span className="text-[13px] text-muted">Normal</span>
                    )}
                  </td>
                  <td
                    className={cx(
                      'px-4 py-3 text-right font-bold tabular-nums',
                      shop.balance < 0 && 'text-danger',
                    )}
                  >
                    {money(shop.balance)}
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-muted">
                    {shop.lastOrderAt ? dateTime(shop.lastOrderAt) : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {list.pages > 1 ? (
        <div className="mt-4 flex items-center justify-between text-[14px] font-bold">
          {list.page > 1 ? (
            <Link
              href={hrefWith({ q }, { page: String(list.page - 1) })}
              className="text-accent hover:underline"
            >
              ← Précédentes
            </Link>
          ) : (
            <span />
          )}
          <span className="text-muted">
            Page {list.page} sur {list.pages}
          </span>
          {list.page < list.pages ? (
            <Link
              href={hrefWith({ q }, { page: String(list.page + 1) })}
              className="text-accent hover:underline"
            >
              Suivantes →
            </Link>
          ) : (
            <span />
          )}
        </div>
      ) : null}
    </div>
  );
}
