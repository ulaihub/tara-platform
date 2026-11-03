import {
  cashCarried,
  ineligibilities,
  offersForRound,
  type RiderSnapshot,
  score,
} from './rider-scoring.js';

const base: RiderSnapshot = {
  riderId: 'r1',
  distanceMeters: 1_000,
  activeOrders: 0,
  hasPendingOffer: false,
  documentsValid: true,
  cashHeld: 0,
  cashLimit: 50_000,
  ratingSum: 0,
  ratingCount: 0,
};

describe('choix du livreur (D1, D4)', () => {
  it('écarte un livreur aux pièces expirées, au plafond d’espèces ou déjà occupé', () => {
    expect(ineligibilities(base, 0)).toEqual([]);
    expect(ineligibilities({ ...base, documentsValid: false }, 0)).toEqual(['DOCUMENTS']);
    expect(ineligibilities({ ...base, cashHeld: 45_000 }, 6_000)).toEqual(['CASH_LIMIT']);
    expect(ineligibilities({ ...base, activeOrders: 2 }, 0)).toEqual(['TOO_MANY_ORDERS']);
    expect(ineligibilities({ ...base, hasPendingOffer: true }, 0)).toEqual(['PENDING_OFFER']);
  });

  it('préfère le plus proche, puis corrige par les courses en cours, les espèces et la note', () => {
    expect(score(base)).toBe(1_000);
    expect(score({ ...base, activeOrders: 1 })).toBe(3_000);
    expect(score({ ...base, cashHeld: 25_000 })).toBe(1_500);
    // 4,8/5 sur 10 avis : 400 m de bonus.
    expect(score({ ...base, ratingSum: 48, ratingCount: 10 })).toBe(600);
    // Trop peu d'avis : la note ne compte pas.
    expect(score({ ...base, ratingSum: 5, ratingCount: 1 })).toBe(1_000);
  });

  it('compte les espèces de la course : contre-remboursement et frais payés en espèces', () => {
    expect(cashCarried({ codAmount: 10_000, totalPrice: 1_500, feePaymentMethod: 'CASH' })).toBe(
      11_500,
    );
    expect(cashCarried({ codAmount: 0, totalPrice: 1_500, feePaymentMethod: 'MOMO_MTN' })).toBe(0);
  });

  it('propose à un seul livreur, puis diffuse après trois refus (D2)', () => {
    expect([1, 2, 3, 4, 5].map((round) => offersForRound(round, 3, 5))).toEqual([1, 1, 1, 5, 5]);
  });
});
