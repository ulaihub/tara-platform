import type { Env } from '../config/env.js';

export type WaitingRules = Pick<
  Env,
  'WAITING_FREE_MINUTES' | 'WAITING_STEP_MINUTES' | 'WAITING_FEE_PER_STEP'
>;

/**
 * Frais d'attente au point d'enlèvement (D) : gratuits pendant les premières minutes, puis un
 * montant par tranche commencée. Ex. avec 10 min gratuites et 100 F par 5 min : 12 min, 100 F ;
 * 16 min, 200 F.
 */
export function waitingFeeFor(
  arrivedAt: Date | null,
  pickedUpAt: Date | null,
  rules: WaitingRules,
): number {
  if (!arrivedAt || !pickedUpAt) return 0;
  const minutes = (pickedUpAt.getTime() - arrivedAt.getTime()) / 60_000;
  const over = minutes - rules.WAITING_FREE_MINUTES;
  if (over <= 0) return 0;
  return Math.ceil(over / rules.WAITING_STEP_MINUTES) * rules.WAITING_FEE_PER_STEP;
}
