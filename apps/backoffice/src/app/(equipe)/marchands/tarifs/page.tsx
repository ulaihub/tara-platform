import type { Metadata } from 'next';
import { Badge } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime, money } from '@/lib/format';
import {
  BOOST_STATUS,
  describeGrid,
  EXAMPLE_TRIPS,
  editableGridOf,
  km,
  percent,
  PRICING_ROLES,
  SURCHARGE_LABELS,
  simpleGridOf,
} from '@/lib/merchants';
import type { PriceSimulation, PricingGrid, PricingSettings, RiderBoost } from '@/lib/schemas';
import { MerchantsHeader } from '../tabs';
import { BoostForm, GridEditor, SettingsForm, StopBoost, SurchargeToggle } from './forms';

export const metadata: Metadata = { title: 'Tarifs et primes' };

const CITY = 'Douala';

/** Prix de la grille en vigueur pour les trajets d'exemple, calculés par le serveur. */
async function examples(grid: PricingGrid): Promise<PriceSimulation['rows']> {
  const result = await staffApi<PriceSimulation>('/admin/pricing-grids/simulate', {
    method: 'POST',
    body: {
      riderShareBps: grid.riderShareBps,
      perKmBeyondLastTier: grid.perKmBeyondLastTier,
      tiers: grid.tiers,
      distancesMeters: EXAMPLE_TRIPS.map((trip) => trip.meters),
    },
  });
  return result.rows;
}

/**
 * Tarifs et primes (H4) : la grille en vigueur et ses suppléments, le tarif pro des boutiques,
 * la prime d'approche et les primes de renfort des livreurs. Tout se règle ici, sans nouvelle
 * version des apps ; les commandes passées gardent leur prix.
 */
export default async function PricingPage() {
  await requireStaff(PRICING_ROLES);
  const [grids, settings, boosts] = await Promise.all([
    staffApi<PricingGrid[]>('/admin/pricing-grids', { query: { city: CITY } }),
    staffApi<PricingSettings>(`/admin/pricing-settings/${CITY}`),
    staffApi<RiderBoost[]>('/admin/rider-boosts', { query: { city: CITY } }),
  ]);
  const moto = grids.find((grid) => grid.active && grid.vehicleType === 'MOTORBIKE');
  const tricycle = grids.find((grid) => grid.vehicleType === 'TRICYCLE');
  const [rows, tricycleRows] = await Promise.all([
    moto ? examples(moto) : Promise.resolve([]),
    tricycle ? examples(tricycle) : Promise.resolve([]),
  ]);
  const simple = moto ? simpleGridOf(moto) : null;
  const tricycleSimple = tricycle ? simpleGridOf(tricycle) : null;
  const running = boosts.filter((boost) => boost.status === 'ACTIVE');

  return (
    <div className="mx-auto max-w-[1280px]">
      <MerchantsHeader
        current="/marchands/tarifs"
        aside="Prix calculés par le serveur et affichés au client avant qu’il commande."
      />

      <div className="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_420px]">
        <div className="space-y-5">
          <section className="bo-glass rounded-[22px] p-5 shadow-card">
            <div className="mb-3 flex flex-wrap items-start gap-3">
              <div className="flex-1">
                <h2 className="font-display text-[17px] font-bold">Grille moto de {CITY}</h2>
                {moto ? (
                  <p className="text-[13px] text-muted">
                    En vigueur depuis le {dateTime(moto.validFrom)} · {moto.name}
                  </p>
                ) : null}
              </div>
              {moto ? <Badge tone="ok">Part du livreur {percent(moto.riderShareBps)}</Badge> : null}
            </div>
            {moto ? (
              <>
                <p className="mb-4 text-[16px] font-bold">
                  {simple
                    ? describeGrid(simple)
                    : `${moto.tiers.length} paliers, puis +${money(moto.perKmBeyondLastTier)} par km.`}
                </p>
                <div className="relative overflow-x-auto">
                  <table className="w-full text-left text-[14px]">
                    <thead className="border-b border-line text-[12px] font-bold text-faint uppercase">
                      <tr>
                        <th className="py-2">Exemple de trajet</th>
                        <th className="py-2 text-right">Client</th>
                        <th className="py-2 text-right">Livreur</th>
                        <th className="py-2 text-right">Tara</th>
                      </tr>
                    </thead>
                    <tbody>
                      {EXAMPLE_TRIPS.map((trip, index) => (
                        <tr key={trip.label} className="border-b border-line last:border-0">
                          <td className="py-2.5">
                            <span className="font-semibold">{trip.label}</span>
                            <span className="ml-2 text-[12px] text-faint">{km(trip.meters)}</span>
                          </td>
                          <td className="py-2.5 pl-2 text-right font-bold whitespace-nowrap tabular-nums">
                            {rows[index] ? money(rows[index].price) : '—'}
                          </td>
                          <td className="py-2.5 pl-2 text-right whitespace-nowrap tabular-nums">
                            {rows[index] ? money(rows[index].riderEarning) : '—'}
                          </td>
                          <td className="py-2.5 pl-2 text-right whitespace-nowrap tabular-nums text-muted">
                            {rows[index] ? money(rows[index].platformShare) : '—'}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <p className="mt-2 mb-4 text-[12px] text-faint">
                  Distances par la route, de centre de quartier à centre de quartier ; l’app calcule
                  d’adresse exacte à adresse exacte. Sans suppléments ni remise.
                </p>
                <GridEditor currentId={moto.id} initial={editableGridOf(moto)} current={rows} />
              </>
            ) : (
              <p className="text-muted">
                Aucune grille moto en vigueur : les commandes sont refusées.
              </p>
            )}
          </section>

          {moto ? (
            <section className="bo-glass rounded-[22px] p-5 shadow-card">
              <h2 className="mb-1 font-display text-[17px] font-bold">Suppléments</h2>
              <p className="mb-3 text-[13px] text-muted">
                Annoncés au client avant de commander. Un supplément coupé ne s’applique plus aux
                nouvelles commandes.
              </p>
              <ul className="divide-y divide-line">
                {moto.surcharges.map((surcharge) => (
                  <li key={surcharge.code} className="flex items-center gap-3 py-2.5">
                    <div className="flex-1">
                      <p className="text-[14px] font-bold">
                        {SURCHARGE_LABELS[surcharge.code].label}
                      </p>
                      <p className="text-[12px] text-muted">
                        {SURCHARGE_LABELS[surcharge.code].hint}
                      </p>
                    </div>
                    <span className="text-[14px] font-bold tabular-nums">
                      {surcharge.amount !== null
                        ? `+${money(surcharge.amount)}`
                        : `${percent(surcharge.percentBps ?? 0)} du prix`}
                    </span>
                    <SurchargeToggle
                      gridId={moto.id}
                      code={surcharge.code}
                      active={surcharge.active}
                    />
                  </li>
                ))}
              </ul>
            </section>
          ) : null}

          <section className="bo-glass rounded-[22px] p-5 shadow-card">
            <h2 className="font-display text-[17px] font-bold">Gros objets (tricycle)</h2>
            {tricycle ? (
              <>
                <p className="mt-1 text-[14px] text-muted">
                  {tricycle.active ? (
                    <Badge tone="ok">Ouvert</Badge>
                  ) : (
                    <Badge tone="warn">Pas encore ouvert</Badge>
                  )}{' '}
                  {tricycleSimple
                    ? describeGrid(tricycleSimple)
                    : `${[...tricycle.tiers]
                        .sort((a, b) => a.upToMeters - b.upToMeters)
                        .map((tier) => `${money(tier.price)} jusqu’à ${km(tier.upToMeters)}`)
                        .join(', ')}, puis +${money(tricycle.perKmBeyondLastTier)} par km.`}{' '}
                  Part du livreur {percent(tricycle.riderShareBps)}.
                </p>
                <div className="mt-3">
                  <GridEditor
                    currentId={tricycle.id}
                    initial={editableGridOf(tricycle)}
                    current={tricycleRows}
                    label="Modifier la grille tricycle"
                  />
                </div>
              </>
            ) : (
              <p className="mt-1 text-muted">Aucune grille tricycle.</p>
            )}
          </section>
        </div>

        <div className="space-y-5">
          <section className="bo-glass rounded-[22px] p-5 shadow-card">
            <h2 className="mb-4 font-display text-[17px] font-bold">Remises et primes</h2>
            <SettingsForm
              tiers={settings.volumeDiscounts}
              approachBonusAmount={settings.approachBonusAmount}
              approachBonusFromMeters={settings.approachBonusFromMeters}
            />
            {settings.updatedAt === null ? (
              <p className="mt-3 text-[12px] text-faint">Valeurs validées au lancement.</p>
            ) : (
              <p className="mt-3 text-[12px] text-faint">
                Modifiées le {dateTime(settings.updatedAt)}.
              </p>
            )}
          </section>

          <section className="bo-glass rounded-[22px] p-5 shadow-card">
            <h2 className="font-display text-[17px] font-bold">Primes de renfort</h2>
            <p className="mt-1 mb-4 text-[13px] text-muted">
              Quand il manque des livreurs (pluie, heures de pointe), Tara ajoute une prime à chaque
              course au lieu d’augmenter le prix du client.
            </p>
            {running.length > 0 ? (
              <p className="mb-3 rounded-2xl bg-ok-bg px-3 py-2 text-[13px] font-bold text-ok">
                En cours : +{money(running[0]?.amount ?? 0)} par course jusqu’à{' '}
                {dateTime(running[0]?.endsAt ?? '')}.
              </p>
            ) : null}
            <BoostForm />
            {boosts.length > 0 ? (
              <ul className="mt-4 divide-y divide-line">
                {boosts.slice(0, 8).map((boost) => (
                  <li key={boost.id} className="flex items-start gap-3 py-2.5">
                    <div className="flex-1">
                      <p className="text-[14px] font-bold">
                        +{money(boost.amount)} · {boost.reason}
                      </p>
                      <p className="text-[12px] text-muted">
                        {dateTime(boost.startsAt)} → {dateTime(boost.endsAt)}
                        {boost.createdBy ? ` · ${boost.createdBy}` : ''}
                      </p>
                      <p className="text-[12px] text-muted">
                        {boost.orders} course{boost.orders > 1 ? 's' : ''} · {money(boost.paid)}{' '}
                        versés
                      </p>
                    </div>
                    <span
                      className={`rounded-full px-2 py-0.5 text-[12px] font-bold ${BOOST_STATUS[boost.status].tone}`}
                    >
                      {BOOST_STATUS[boost.status].label}
                    </span>
                    {boost.status === 'ACTIVE' || boost.status === 'SCHEDULED' ? (
                      <StopBoost boostId={boost.id} />
                    ) : null}
                  </li>
                ))}
              </ul>
            ) : null}
          </section>
        </div>
      </div>
    </div>
  );
}
