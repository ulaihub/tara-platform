import { mobileMoneySurcharge, payoutCharge } from './mobile-money-fees.js';

describe('Frais Mobile Money répercutés', () => {
  it('encaissement : Tara garde au moins le montant une fois les frais retenus', () => {
    expect(mobileMoneySurcharge(1500, 600)).toBe(96);
    expect(mobileMoneySurcharge(10_000, 600)).toBe(639);
    expect(mobileMoneySurcharge(1500, 0)).toBe(0);
    for (const amount of [100, 1000, 1500, 2350, 6000, 49_999, 500_000]) {
      for (const bps of [250, 350, 600]) {
        const surcharge = mobileMoneySurcharge(amount, bps);
        const kept = amount + surcharge - ((amount + surcharge) * bps) / 10_000;
        expect(kept).toBeGreaterThanOrEqual(amount);
        // Jamais plus d'un franc au-dessus de ce qu'il faut.
        expect(kept - amount).toBeLessThan(1);
      }
    }
  });

  it('reversement : les frais du prestataire sont couverts par la retenue', () => {
    expect(payoutCharge(10_000, 250)).toBe(244);
    expect(payoutCharge(10_000, 0)).toBe(0);
    for (const amount of [500, 2000, 9999, 50_000, 200_000]) {
      const charge = payoutCharge(amount, 250);
      const sent = amount - charge;
      expect(charge).toBeGreaterThanOrEqual((sent * 250) / 10_000);
      expect(charge - (sent * 250) / 10_000).toBeLessThan(1);
    }
  });
});
