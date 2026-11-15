import {
  cashCarried,
  ineligibilities,
  offersForRound,
  type RiderSnapshot,
  score,
  trustedForValue,
} from './rider-scoring.js';

const base: RiderSnapshot = {
  riderId: 'r1',
  vehicleType: 'MOTORBIKE',
  safetyAlertOpen: false,
  distanceMeters: 1_000,
  activeOrders: 0,
  hasPendingOffer: false,
  documentsValid: true,
  termsAccepted: true,
  cashOverdue: false,
  availableBalance: 20_000,
  ratingSum: 0,
  ratingCount: 0,
  deliveredCount: 0,
};

const need = (cash: number, packageSize: 'M' | 'BULKY' = 'M') => ({ cash, packageSize });

describe('choix du livreur (D1, D4)', () => {
  it('écarte un livreur aux pièces expirées, au solde insuffisant ou déjà occupé', () => {
    expect(ineligibilities(base, need(0))).toEqual([]);
    expect(ineligibilities({ ...base, documentsValid: false }, need(0))).toEqual(['DOCUMENTS']);
    // Solde prépayé : il doit couvrir l'argent à encaisser ; une course déjà payée passe.
    expect(ineligibilities(base, need(20_000))).toEqual([]);
    expect(ineligibilities(base, need(20_001))).toEqual(['BALANCE_TOO_LOW']);
    expect(ineligibilities({ ...base, availableBalance: 0 }, need(0))).toEqual([]);
    expect(ineligibilities({ ...base, activeOrders: 2 }, need(0))).toEqual(['TOO_MANY_ORDERS']);
    expect(ineligibilities({ ...base, hasPendingOffer: true }, need(0))).toEqual(['PENDING_OFFER']);
    // Espèces non déposées dans le délai (G5) : plus de courses jusqu'au dépôt.
    expect(ineligibilities({ ...base, cashOverdue: true }, need(0))).toEqual(['CASH_OVERDUE']);
  });

  it('réserve les gros objets aux tricycles et camionnettes', () => {
    expect(ineligibilities(base, need(0, 'BULKY'))).toEqual(['VEHICLE']);
    expect(ineligibilities({ ...base, vehicleType: 'TRICYCLE' }, need(0, 'BULKY'))).toEqual([]);
    expect(ineligibilities({ ...base, vehicleType: 'CAR' }, need(0, 'BULKY'))).toEqual([]);
    // Un tricycle prend aussi les petits colis.
    expect(ineligibilities({ ...base, vehicleType: 'TRICYCLE' }, need(0))).toEqual([]);
  });

  it('ne propose rien à un livreur dont le SOS n’est pas clos', () => {
    expect(ineligibilities({ ...base, safetyAlertOpen: true }, need(0))).toEqual(['SAFETY_ALERT']);
  });

  it('préfère le plus proche, puis corrige par les courses en cours et la note', () => {
    expect(score(base)).toBe(1_000);
    expect(score({ ...base, activeOrders: 1 })).toBe(3_000);
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

  it('confiance progressive : la valeur déclarée du colis suit l’expérience du livreur', () => {
    const rider = (deliveredCount: number, ratingSum = 0, ratingCount = 0) => ({
      ...base,
      deliveredCount,
      ratingSum,
      ratingCount,
    });
    // Sans valeur déclarée ou jusqu'à 25 000 F : tout livreur.
    expect(trustedForValue(rider(0), null)).toBe(true);
    expect(trustedForValue(rider(0), 25_000)).toBe(true);
    // Au-delà : 20 livraisons faites.
    expect(trustedForValue(rider(19), 25_001)).toBe(false);
    expect(trustedForValue(rider(20), 60_000)).toBe(true);
    // Au-delà de 100 000 F : 50 livraisons et une note d'au moins 4,5 sur 5 avis ou plus.
    expect(trustedForValue(rider(49, 50, 10), 150_000)).toBe(false);
    expect(trustedForValue(rider(50, 18, 4), 150_000)).toBe(false);
    expect(trustedForValue(rider(50, 22, 5), 150_000)).toBe(false);
    expect(trustedForValue(rider(50, 46, 10), 150_000)).toBe(true);
    expect(ineligibilities(rider(3), { ...need(0), declaredValue: 80_000 })).toEqual([
      'PARCEL_VALUE',
    ]);
  });

  it('propose à un seul livreur, puis diffuse après trois refus (D2)', () => {
    expect([1, 2, 3, 4, 5].map((round) => offersForRound(round, 3, 5))).toEqual([1, 1, 1, 5, 5]);
  });
});
