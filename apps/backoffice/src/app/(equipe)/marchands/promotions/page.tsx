import type { Metadata } from 'next';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime } from '@/lib/format';
import { PRICING_ROLES, PROMO_KIND_LABELS, promoValue } from '@/lib/merchants';
import type { PromoCode } from '@/lib/schemas';
import { PromoForm, PromoToggle } from '../row-actions';
import { MerchantsHeader } from '../tabs';

export const metadata: Metadata = { title: 'Codes promo' };

/**
 * Codes promo (C6, H4) : financés par Tara, ils ne réduisent jamais la part du livreur ; ils
 * ne se cumulent pas avec le tarif pro (le plus avantageux est retenu).
 */
export default async function PromotionsPage() {
  await requireStaff(PRICING_ROLES);
  const promos = await staffApi<PromoCode[]>('/admin/promo-codes');
  const now = Date.now();

  return (
    <div className="mx-auto max-w-[1280px]">
      <MerchantsHeader
        current="/marchands/promotions"
        aside="Financés par Tara : la part du livreur ne baisse pas. Jamais cumulés avec le tarif pro."
      />
      <section className="mb-5 bo-glass rounded-[22px] p-5 shadow-card">
        <h2 className="mb-3 font-display text-[17px] font-bold">Nouveau code</h2>
        <PromoForm />
      </section>
      {promos.length === 0 ? (
        <div className="bo-glass rounded-[22px] px-6 py-16 text-center">
          <p className="font-display text-[18px] font-bold">Aucun code promo</p>
        </div>
      ) : (
        <div className="relative overflow-x-auto bo-glass rounded-[22px] px-2 pb-1 sm:px-3">
          <table className="w-full min-w-[640px] border-separate border-spacing-y-1.5 text-left text-[13px]">
            <thead className="text-[11px] font-extrabold tracking-[.06em] text-faint uppercase">
              <tr>
                <th className="px-3 pb-1">Code</th>
                <th className="px-3 pb-1">Remise</th>
                <th className="px-3 pb-1">Pour qui</th>
                <th className="px-3 pb-1 text-right">Utilisations</th>
                <th className="px-3 pb-1">Valable jusqu’au</th>
                <th className="px-3 pb-1 text-right">
                  <span className="sr-only">État</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {promos.map((promo) => {
                const expired = promo.validTo !== null && Date.parse(promo.validTo) <= now;
                return (
                  <tr key={promo.id} className="">
                    <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px] font-mono font-bold">
                      {promo.code}
                    </td>
                    <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px]">
                      <span className="font-bold">{promoValue(promo.kind, promo.value)}</span>
                      <span className="block text-[12px] text-muted">
                        {PROMO_KIND_LABELS[promo.kind]}
                      </span>
                    </td>
                    <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px] text-muted">
                      {promo.newCustomersOnly ? 'Nouveaux clients' : 'Tous'} · {promo.perUserLimit}{' '}
                      fois par personne
                    </td>
                    <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px] text-right tabular-nums">
                      {promo.redemptions}
                      {promo.maxRedemptions !== null ? ` / ${promo.maxRedemptions}` : ''}
                    </td>
                    <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px] whitespace-nowrap text-muted">
                      {promo.validTo ? dateTime(promo.validTo) : 'Sans limite'}
                      {expired ? <span className="block text-[12px] text-warn">Expiré</span> : null}
                    </td>
                    <td className="bg-track px-3 py-3 first:rounded-l-[14px] last:rounded-r-[14px]">
                      <PromoToggle id={promo.id} active={promo.active} />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
