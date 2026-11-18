import { waitingFeeFor } from './waiting-fee.js';

const RULES = { WAITING_FREE_MINUTES: 10, WAITING_STEP_MINUTES: 5, WAITING_FEE_PER_STEP: 100 };
const at = (minutes: number) => new Date(Date.UTC(2026, 10, 18, 9, 0) + minutes * 60_000);

describe('frais d’attente au point d’enlèvement', () => {
  it.each([
    [0, 0],
    [10, 0],
    [10.5, 100],
    [15, 100],
    [15.2, 200],
    [32, 500],
  ])('%s min d’attente → %i F', (minutes, fee) => {
    expect(waitingFeeFor(at(0), at(minutes), RULES)).toBe(fee);
  });

  it('rien sans arrivée signalée', () => {
    expect(waitingFeeFor(null, at(40), RULES)).toBe(0);
  });
});
