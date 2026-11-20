import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/icon';
import { ROW_CELL, ROW_HEAD, ROW_TABLE } from '@/components/pills';
import { cx } from '@/components/ui';
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
    <div className="mx-auto max-w-[1280px] pb-8">
      <MerchantsHeader
        current="/marchands"
        aside={`Tarif pro, ventes à reverser, dettes · ${list.onProRate} au tarif pro ce mois-ci`}
      />

      <form action="/marchands" role="search" className="mb-3 flex max-w-[420px] gap-2">
        <label className="bo-glass flex h-10 flex-1 items-center gap-2 rounded-xl px-3">
          <Icon name="search" size={16} className="text-faint" />
          <span className="sr-only">Rechercher une boutique</span>
          <input
            name="q"
            defaultValue={q}
            placeholder="Boutique, gérant ou numéro"
            className="w-full bg-transparent text-[13px] focus:outline-none"
          />
        </label>
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

      <section className="bo-glass rounded-[22px] p-3 sm:px-[18px] sm:py-4">
        <div className="mb-2 flex items-center justify-between px-1">
          <h2 className="text-[15px] font-bold">Boutiques</h2>
          <span className="rounded-full bg-[rgba(255,177,92,.16)] px-2.5 py-1 text-[11px] font-extrabold text-accent">
            {list.total} boutique{list.total > 1 ? 's' : ''}
          </span>
        </div>
        {list.items.length === 0 ? (
          <div className="px-6 py-14 text-center">
            <p className="font-display text-[18px] font-bold">Aucune boutique</p>
            <p className="mt-1 text-muted">
              {q ? 'Aucun résultat pour cette recherche.' : 'Les boutiques apparaîtront ici.'}
            </p>
          </div>
        ) : (
          <>
            <ul className="flex flex-col gap-2 md:hidden">
              {list.items.map((shop) => (
                <li key={shop.id} className="relative rounded-[14px] bg-track px-3 py-2.5">
                  <div className="flex items-center gap-2">
                    <Link
                      href={`/marchands/${shop.id}`}
                      className="font-display font-bold after:absolute after:inset-0 after:content-['']"
                    >
                      {shop.shopName}
                    </Link>
                    <span className="ml-auto">
                      <Tier bps={shop.proDiscountBps} />
                    </span>
                  </div>
                  <p className="mt-1 text-[12px] text-muted">
                    {shop.deliveriesThisMonth} livraison{shop.deliveriesThisMonth > 1 ? 's' : ''} ce
                    mois · solde{' '}
                    <b className={cx(shop.balance < 0 ? 'text-danger' : 'text-text')}>
                      {money(shop.balance)}
                    </b>
                  </p>
                </li>
              ))}
            </ul>
            <div className="hidden overflow-x-auto md:block">
              <table className={cx(ROW_TABLE, 'min-w-[720px]')}>
                <thead className={ROW_HEAD}>
                  <tr>
                    <th className="px-3 pb-1">Boutique</th>
                    <th className="px-3 pb-1">Gérant</th>
                    <th className="px-3 pb-1 text-right">Colis / mois</th>
                    <th className="px-3 pb-1">Tarif</th>
                    <th className="px-3 pb-1 text-right">Solde</th>
                    <th className="px-3 pb-1">Dernière commande</th>
                  </tr>
                </thead>
                <tbody>
                  {list.items.map((shop) => (
                    <tr key={shop.id} className="relative transition hover:brightness-95">
                      <td className={ROW_CELL}>
                        <Link
                          href={`/marchands/${shop.id}`}
                          className="font-display font-bold after:absolute after:inset-0 after:content-['']"
                        >
                          {shop.shopName}
                        </Link>
                        {shop.category ? (
                          <span className="block text-[12px] text-muted">{shop.category}</span>
                        ) : null}
                      </td>
                      <td className={ROW_CELL}>
                        {shop.ownerName ?? '—'}
                        <span className="block text-[12px] text-muted">
                          {displayPhone(shop.phone)}
                        </span>
                      </td>
                      <td className={cx(ROW_CELL, 'text-right font-bold tabular-nums')}>
                        {shop.deliveriesThisMonth}
                      </td>
                      <td className={ROW_CELL}>
                        <Tier bps={shop.proDiscountBps} />
                      </td>
                      <td
                        className={cx(
                          ROW_CELL,
                          'text-right font-extrabold tabular-nums',
                          shop.balance < 0 && 'text-danger',
                        )}
                      >
                        {money(shop.balance)}
                      </td>
                      <td className={cx(ROW_CELL, 'whitespace-nowrap text-muted')}>
                        {shop.lastOrderAt ? dateTime(shop.lastOrderAt) : '—'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>

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

/** Tarif de la boutique : pastille verte « Pro −10 % » ou grise « Standard ». */
function Tier({ bps }: { bps: number }) {
  return bps > 0 ? (
    <span className="rounded-md bg-ok-bg px-2 py-0.5 text-[11px] font-extrabold text-ok">
      Pro −{percent(bps)}
    </span>
  ) : (
    <span className="rounded-md bg-track px-2 py-0.5 text-[11px] font-extrabold text-muted">
      Standard
    </span>
  );
}
