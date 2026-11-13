import type { StaffRole } from './session';

/** Indicateurs : toute l'équipe, comme l'API. */
export const METRICS_ROLES: readonly StaffRole[] = ['ADMIN', 'DISPATCHER', 'SUPPORT', 'FINANCE'];

export const PERIODS = [7, 30, 90] as const;
export type Period = (typeof PERIODS)[number];

/** Période demandée dans l'adresse (?jours=7) ; 30 jours par défaut. */
export function periodOf(value: string | undefined): Period {
  const days = Number(value);
  return (PERIODS as readonly number[]).includes(days) ? (days as Period) : 30;
}

/** Taux lisible : 0.874 → « 87,4 % » ; null → « — ». */
export function rate(value: number | null): string {
  if (value === null) return '—';
  return `${(value * 100).toFixed(1).replace('.', ',').replace(',0', '')} %`;
}

/** Durée lisible en minutes : 42 → « 42 min », 95 → « 1 h 35 ». */
export function minutes(value: number | null): string {
  if (value === null) return '—';
  const total = Math.round(value);
  if (total < 60) return `${total} min`;
  const hours = Math.floor(total / 60);
  const rest = total % 60;
  return rest === 0 ? `${hours} h` : `${hours} h ${String(rest).padStart(2, '0')}`;
}

/** Évolution par rapport à la période précédente, en texte ; null sans base de comparaison. */
export function change(current: number, previous: number): { text: string; up: boolean } | null {
  if (previous === 0) return null;
  const delta = Math.round(((current - previous) / previous) * 100);
  if (delta === 0) return { text: 'stable', up: true };
  return { text: `${delta > 0 ? '+' : '−'}${Math.abs(delta)} %`, up: delta > 0 };
}

/** Écart en points entre deux taux : 0.9 et 0.85 → « +5 pts ». */
export function pointsChange(current: number | null, previous: number | null): string | null {
  if (current === null || previous === null) return null;
  const delta = Math.round((current - previous) * 1000) / 10;
  if (delta === 0) return 'stable';
  return `${delta > 0 ? '+' : '−'}${String(Math.abs(delta)).replace('.', ',')} pt${Math.abs(delta) >= 2 ? 's' : ''}`;
}

/** Graduations « rondes » pour l'axe des livraisons (3 lignes au plus, 0 compris). */
export function ticks(max: number): number[] {
  if (max <= 0) return [0];
  const raw = max / 3;
  const magnitude = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 5, 10].map((m) => m * magnitude).find((s) => s >= raw) ?? raw;
  const result: number[] = [];
  for (let value = 0; value <= max + step * 0.001; value += step) result.push(Math.round(value));
  if ((result.at(-1) ?? 0) < max) result.push(Math.round((result.at(-1) ?? 0) + step));
  return result;
}
