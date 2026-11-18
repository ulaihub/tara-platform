import type { Env } from '../config/env.js';

export type WaitingRules = Pick<
  Env,
  'WAITING_FREE_MINUTES' | 'WAITING_STEP_MINUTES' | 'WAITING_FEE_PER_STEP' | 'WAITING_MAX_MINUTES'
>;

/**
 * Frais d'attente au point d'enlèvement (D) : gratuits pendant les premières minutes, puis un
 * montant par tranche commencée ; l'attente n'est comptée que jusqu'au plafond. Ex. avec 10 min
 * gratuites, 100 F par 5 min et 30 min au plus : 12 min, 100 F ; 16 min, 200 F ; 2 h, 400 F.
 */
export function waitingFeeFor(
  arrivedAt: Date | null,
  pickedUpAt: Date | null,
  rules: WaitingRules,
): number {
  if (!arrivedAt || !pickedUpAt) return 0;
  const waited = (pickedUpAt.getTime() - arrivedAt.getTime()) / 60_000;
  const over = Math.min(waited, rules.WAITING_MAX_MINUTES) - rules.WAITING_FREE_MINUTES;
  if (over <= 0) return 0;
  return Math.ceil(over / rules.WAITING_STEP_MINUTES) * rules.WAITING_FEE_PER_STEP;
}

/** Frais d'attente les plus hauts : ceux de l'attente comptée au plus. */
export function waitingFeeMax(rules: WaitingRules): number {
  return waitingFeeFor(new Date(0), new Date(rules.WAITING_MAX_MINUTES * 60_000), rules);
}
