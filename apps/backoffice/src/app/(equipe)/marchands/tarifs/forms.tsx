'use client';

import { useActionState, useEffect, useState, useTransition } from 'react';
import { Icon } from '@/components/icon';
import { cx } from '@/components/ui';
import { money } from '@/lib/format';
import { EXAMPLE_TRIPS, gridProblem, km, type SimpleGrid } from '@/lib/merchants';
import type { PriceSimulation } from '@/lib/schemas';
import {
  type ActionState,
  cancelBoost,
  createBoost,
  saveGrid,
  saveSettings,
  simulateGrid,
  toggleSurcharge,
} from '../actions';

const IDLE: ActionState = { error: null, done: false };

/** Champ sans largeur imposée : la largeur vient de chaque usage (w-full, w-24…). */
const FIELD =
  'block h-10 rounded-xl border border-line bg-panel px-3 text-[14px] tabular-nums focus:border-accent-line focus:outline-none';
const INPUT = `${FIELD} w-full`;

function Feedback({ state, done }: { state: ActionState; done?: string }) {
  if (state.error) {
    return (
      <p role="alert" className="mt-2 text-[13px] font-bold text-danger">
        {state.error}
      </p>
    );
  }
  return state.done && done ? (
    <p role="status" className="mt-2 text-[13px] font-bold text-ok">
      {done}
    </p>
  ) : null;
}

type Rows = PriceSimulation['rows'];

const GRID_FIELDS: { key: keyof SimpleGrid; label: string; suffix: string }[] = [
  { key: 'startPrice', label: 'Prix de départ', suffix: 'F' },
  { key: 'startKm', label: 'jusqu’à', suffix: 'km' },
  { key: 'stepPrice', label: 'puis, par km', suffix: 'F' },
  { key: 'untilKm', label: 'jusqu’à', suffix: 'km' },
  { key: 'beyondPerKm', label: 'au-delà, par km', suffix: 'F' },
  { key: 'riderSharePercent', label: 'Part du livreur', suffix: '%' },
];

/**
 * Modifier la grille : chaque changement est recalculé par le serveur sur des trajets réels
 * de Douala, comparé à la grille en vigueur, puis enregistré après confirmation.
 */
export function GridEditor({
  currentId,
  initial,
  current,
  label = 'Modifier la grille',
}: {
  currentId: string;
  initial: SimpleGrid;
  current: Rows;
  label?: string;
}) {
  const [open, setOpen] = useState(false);
  const [grid, setGrid] = useState(initial);
  const [rows, setRows] = useState<Rows>(current);
  const [problem, setProblem] = useState<string | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [computing, startComputing] = useTransition();
  const [state, save, saving] = useActionState(saveGrid, IDLE);

  useEffect(() => {
    if (!open) return;
    const local = gridProblem(grid);
    setProblem(local);
    if (local) return;
    const timer = setTimeout(() => {
      startComputing(async () => {
        const result = await simulateGrid(
          grid,
          EXAMPLE_TRIPS.map((trip) => trip.meters),
        );
        if ('error' in result) setProblem(result.error);
        else setRows(result);
      });
    }, 350);
    return () => clearTimeout(timer);
  }, [grid, open]);

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="inline-flex min-h-10 items-center gap-2 rounded-xl border border-line px-4 text-[14px] font-bold hover:border-accent-line"
      >
        {label}
      </button>
    );
  }

  return (
    <form action={save} className="mt-4 rounded-2xl border border-accent-line bg-panel-soft p-4">
      <input type="hidden" name="currentId" value={currentId} />
      <p className="mb-3 text-[14px] font-bold">Nouvelle grille</p>
      <div className="grid grid-cols-2 gap-x-4 gap-y-3 md:grid-cols-3">
        {GRID_FIELDS.map((item) => (
          <label key={item.key} className="block min-w-0">
            <span className="block truncate text-[12px] font-bold whitespace-nowrap text-muted">
              {item.label}
            </span>
            <span className="mt-1 flex items-center gap-1.5">
              <input
                name={item.key}
                inputMode="numeric"
                value={Number.isNaN(grid[item.key]) ? '' : String(grid[item.key])}
                onChange={(event) => {
                  setConfirming(false);
                  setGrid({ ...grid, [item.key]: Number(event.target.value.replace(',', '.')) });
                }}
                className={INPUT}
              />
              <span className="w-5 shrink-0 text-[13px] font-bold text-muted">{item.suffix}</span>
            </span>
          </label>
        ))}
      </div>

      <table className="mt-4 w-full text-left text-[13px]">
        <thead className="text-[11px] font-bold text-faint uppercase">
          <tr>
            <th className="py-2">Trajet</th>
            <th className="py-2 text-right">Aujourd’hui</th>
            <th className="py-2 text-right">Nouvelle grille</th>
            <th className="py-2 text-right">Livreur</th>
            <th className="py-2 text-right">Tara</th>
          </tr>
        </thead>
        <tbody>
          {EXAMPLE_TRIPS.map((trip, index) => {
            const before = current[index];
            const after = rows[index];
            const diff = before && after ? after.price - before.price : 0;
            return (
              <tr key={trip.label} className="border-t border-line">
                <td className="py-2">
                  <span className="font-semibold">{trip.label}</span>
                  <span className="block text-[12px] text-faint">{km(trip.meters)}</span>
                </td>
                <td className="py-2 text-right text-muted tabular-nums">
                  {before ? money(before.price) : '—'}
                </td>
                <td
                  className={cx(
                    'py-2 text-right font-bold tabular-nums',
                    computing && 'opacity-50',
                  )}
                >
                  {after ? money(after.price) : '—'}
                  {diff !== 0 ? (
                    <span className={cx('block text-[12px]', diff > 0 ? 'text-warn' : 'text-ok')}>
                      {diff > 0 ? '+' : '−'}
                      {money(Math.abs(diff))}
                    </span>
                  ) : null}
                </td>
                <td className="py-2 text-right tabular-nums">
                  {after ? money(after.riderEarning) : '—'}
                </td>
                <td className="py-2 text-right tabular-nums">
                  {after ? money(after.platformShare) : '—'}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>

      {problem ? (
        <p role="alert" className="mt-3 text-[13px] font-bold text-warn">
          {problem}
        </p>
      ) : null}
      <div className="mt-4 flex flex-wrap items-center gap-2">
        {confirming ? (
          <>
            <span className="text-[13px] font-bold">
              Les prochaines commandes utiliseront cette grille ; les commandes passées gardent leur
              prix.
            </span>
            <button
              type="submit"
              disabled={saving || problem !== null}
              className="min-h-10 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
            >
              {saving ? 'Enregistrement…' : 'Confirmer'}
            </button>
          </>
        ) : (
          <button
            type="button"
            disabled={problem !== null}
            onClick={() => setConfirming(true)}
            className="min-h-10 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
          >
            Enregistrer la nouvelle grille
          </button>
        )}
        <button
          type="button"
          onClick={() => {
            setOpen(false);
            setConfirming(false);
            setGrid(initial);
            setRows(current);
          }}
          className="min-h-10 rounded-xl px-3 text-[14px] font-bold text-muted hover:text-text"
        >
          Annuler
        </button>
      </div>
      <Feedback state={state} done="Nouvelle grille en vigueur." />
    </form>
  );
}

/** Interrupteur d'un supplément de la grille en vigueur. */
export function SurchargeToggle({
  gridId,
  code,
  active,
}: {
  gridId: string;
  code: string;
  active: boolean;
}) {
  const [state, action, pending] = useActionState(toggleSurcharge, IDLE);
  return (
    <form action={action} className="flex flex-col items-end">
      <input type="hidden" name="gridId" value={gridId} />
      <input type="hidden" name="code" value={code} />
      <input type="hidden" name="active" value={active ? 'false' : 'true'} />
      <button
        type="submit"
        disabled={pending}
        aria-pressed={active}
        className={cx(
          'min-h-9 min-w-[96px] rounded-xl px-3 text-[13px] font-extrabold disabled:opacity-60',
          active ? 'bg-ok-bg text-ok' : 'bg-track text-muted',
        )}
      >
        {active ? 'Activé' : 'Coupé'}
      </button>
      <Feedback state={state} />
    </form>
  );
}

/** Tarif pro des boutiques et prime d'approche des livreurs. */
export function SettingsForm({
  tiers,
  approachBonusAmount,
  approachBonusFromMeters,
}: {
  tiers: { fromDeliveries: number; percentBps: number }[];
  approachBonusAmount: number;
  approachBonusFromMeters: number;
}) {
  const [state, action, pending] = useActionState(saveSettings, IDLE);
  return (
    <form action={action} className="space-y-5">
      <fieldset>
        <legend className="text-[14px] font-bold">Tarif pro des boutiques</legend>
        <p className="mb-3 text-[13px] text-muted">
          Remise automatique selon les livraisons réussies du mois, prise sur la part de Tara.
          Laissez une ligne vide pour la retirer.
        </p>
        <div className="space-y-2">
          {[0, 1, 2].map((index) => (
            <div key={index} className="flex flex-wrap items-center gap-2 text-[14px]">
              <span className="text-muted">À partir de</span>
              <input
                name={`from${index}`}
                inputMode="numeric"
                defaultValue={tiers[index]?.fromDeliveries ?? ''}
                aria-label={`Palier ${index + 1} : livraisons du mois`}
                className={cx(FIELD, 'w-24')}
              />
              <span className="text-muted">livraisons :</span>
              <span className="font-bold">−</span>
              <input
                name={`percent${index}`}
                inputMode="decimal"
                defaultValue={tiers[index] ? tiers[index].percentBps / 100 : ''}
                aria-label={`Palier ${index + 1} : remise en pourcentage`}
                className={cx(FIELD, 'w-20')}
              />
              <span className="font-bold text-muted">%</span>
            </div>
          ))}
        </div>
      </fieldset>
      <fieldset>
        <legend className="text-[14px] font-bold">Prime d’approche des livreurs</legend>
        <p className="mb-3 text-[13px] text-muted">
          Payée par Tara quand le vendeur est loin du livreur au moment de la proposition (0 F pour
          la couper).
        </p>
        <div className="grid grid-cols-2 gap-3">
          <label className="block">
            <span className="text-[12px] font-bold text-muted">Montant de la prime</span>
            <span className="mt-1 flex items-center gap-1.5">
              <input
                name="approachBonusAmount"
                inputMode="numeric"
                defaultValue={approachBonusAmount}
                className={INPUT}
              />
              <span className="w-6 shrink-0 text-[13px] font-bold text-muted">F</span>
            </span>
          </label>
          <label className="block">
            <span className="text-[12px] font-bold text-muted">Vendeur à plus de</span>
            <span className="mt-1 flex items-center gap-1.5">
              <input
                name="approachBonusFromKm"
                inputMode="decimal"
                defaultValue={approachBonusFromMeters / 1000}
                className={INPUT}
              />
              <span className="w-6 shrink-0 text-[13px] font-bold text-muted">km</span>
            </span>
          </label>
        </div>
      </fieldset>
      <button
        type="submit"
        disabled={pending}
        className="min-h-10 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
      >
        {pending ? 'Enregistrement…' : 'Enregistrer'}
      </button>
      <Feedback state={state} done="Réglages enregistrés : ils s’appliquent dès maintenant." />
    </form>
  );
}

/** Lancer une prime de renfort : montant par course, raison, durée. */
export function BoostForm() {
  const [state, action, pending] = useActionState(createBoost, IDLE);
  return (
    <form action={action} className="flex flex-wrap items-end gap-3">
      <label className="block">
        <span className="text-[12px] font-bold text-muted">Par course</span>
        <span className="mt-1 flex items-center gap-1.5">
          <input
            name="amount"
            inputMode="numeric"
            defaultValue={300}
            className={cx(FIELD, 'w-24')}
          />
          <span className="text-[13px] font-bold text-muted">F</span>
        </span>
      </label>
      <label className="block min-w-[200px] flex-1">
        <span className="text-[12px] font-bold text-muted">Raison</span>
        <input
          name="reason"
          defaultValue="Forte pluie"
          maxLength={120}
          className={cx(INPUT, 'mt-1')}
        />
      </label>
      <label className="block">
        <span className="text-[12px] font-bold text-muted">Pendant</span>
        <select name="hours" defaultValue="2" className={cx(FIELD, 'mt-1 w-32')}>
          {[1, 2, 3, 4, 6, 8, 12].map((hours) => (
            <option key={hours} value={hours}>
              {hours} heure{hours > 1 ? 's' : ''}
            </option>
          ))}
        </select>
      </label>
      <button
        type="submit"
        disabled={pending}
        className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-brand px-4 text-[14px] font-extrabold text-on-brand disabled:opacity-60"
      >
        <Icon name="moto" size={16} />
        {pending ? 'Lancement…' : 'Lancer la prime'}
      </button>
      <div className="w-full">
        <Feedback state={state} done="Prime lancée : elle s’ajoute aux prochaines propositions." />
      </div>
    </form>
  );
}

export function StopBoost({ boostId }: { boostId: string }) {
  const [state, action, pending] = useActionState(cancelBoost, IDLE);
  return (
    <form action={action} className="flex flex-col items-end">
      <input type="hidden" name="boostId" value={boostId} />
      <button
        type="submit"
        disabled={pending}
        className="min-h-9 rounded-xl border border-danger/40 px-3 text-[13px] font-extrabold text-danger hover:bg-danger-bg disabled:opacity-60"
      >
        {pending ? 'Arrêt…' : 'Arrêter'}
      </button>
      <Feedback state={state} />
    </form>
  );
}
