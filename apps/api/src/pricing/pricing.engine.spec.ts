import {
  approachBonusFor,
  basePriceFor,
  computePrice,
  discountFor,
  type GridRules,
  vehicleCarries,
  vehicleForParcel,
  valueFeeFor,
  volumeDiscountFor,
} from './pricing.engine.js';

/** Grille de Douala du business plan. */
const DOUALA: GridRules = {
  riderShareBps: 8000,
  perKmBeyondLastTier: 150,
  tiers: [
    { upToMeters: 10_000, price: 1500 },
    { upToMeters: 5_000, price: 1000 },
    { upToMeters: 15_000, price: 2000 },
  ],
  surcharges: [
    { code: 'EXPRESS', amount: 500, percentBps: null, active: true },
    { code: 'HEAVY_PARCEL', amount: 1000, percentBps: null, active: true },
    { code: 'NIGHT', amount: 500, percentBps: null, active: true },
    { code: 'WEATHER', amount: 300, percentBps: null, active: false },
    { code: 'FAILED_ATTEMPT', amount: null, percentBps: 5000, active: true },
    { code: 'RETURN', amount: null, percentBps: 5000, active: true },
  ],
};

/** 10 h à Douala (UTC+1). */
const DAY = new Date('2026-11-02T09:00:00Z');

describe('prix de base par paliers', () => {
  it.each([
    [0, 1000],
    [5_000, 1000],
    [5_001, 1500],
    [10_000, 1500],
    [14_999, 2000],
    [15_000, 2000],
    [15_001, 2150],
    [16_000, 2150],
    [16_001, 2300],
    [22_500, 3200],
  ])('%i m → %i FCFA', (meters, price) => {
    expect(basePriceFor(DOUALA, meters)).toBe(price);
  });

  it('refuse une grille sans palier', () => {
    expect(() => basePriceFor({ tiers: [], perKmBeyondLastTier: 100 }, 1000)).toThrow();
  });
});

describe('prix complet', () => {
  it('livraison simple de 7 km : 1 500 FCFA, 1 200 pour le livreur, 300 pour Tara', () => {
    expect(
      computePrice(DOUALA, { distanceMeters: 7_000, packageSize: 'M', isExpress: false, at: DAY }),
    ).toEqual({
      basePrice: 1500,
      surcharges: [],
      surchargesTotal: 0,
      subtotal: 1500,
      discountTotal: 0,
      discountSource: null,
      proDiscountBps: 0,
      totalPrice: 1500,
      riderEarning: 1200,
      platformFee: 300,
      retryFee: 750,
      returnFee: 750,
      valueFee: 0,
    });
  });

  it('cumule express et colis XL', () => {
    const price = computePrice(DOUALA, {
      distanceMeters: 3_000,
      packageSize: 'XL',
      isExpress: true,
      at: DAY,
    });
    expect(price.surcharges).toEqual([
      { code: 'EXPRESS', amount: 500 },
      { code: 'HEAVY_PARCEL', amount: 1000 },
    ]);
    expect(price).toMatchObject({ subtotal: 2500, riderEarning: 2000, platformFee: 500 });
  });

  it.each([
    ['2026-11-02T18:59:00Z', false], // 19 h 59 à Douala
    ['2026-11-02T19:00:00Z', true], // 20 h 00
    ['2026-11-03T04:59:00Z', true], // 5 h 59
    ['2026-11-03T05:00:00Z', false], // 6 h 00
  ])('supplément de nuit à %s (UTC) : %s', (iso, night) => {
    const price = computePrice(DOUALA, {
      distanceMeters: 1_000,
      packageSize: 'S',
      isExpress: false,
      at: new Date(iso),
    });
    expect(price.surcharges.some((s) => s.code === 'NIGHT')).toBe(night);
  });

  it('applique le supplément météo seulement quand l’équipe l’active', () => {
    const rainy: GridRules = {
      ...DOUALA,
      surcharges: DOUALA.surcharges.map((s) => (s.code === 'WEATHER' ? { ...s, active: true } : s)),
    };
    const price = computePrice(rainy, {
      distanceMeters: 1_000,
      packageSize: 'S',
      isExpress: false,
      at: DAY,
    });
    expect(price.surcharges).toEqual([{ code: 'WEATHER', amount: 300 }]);
  });

  it('n’applique jamais au devis les frais d’échec et de retour', () => {
    const price = computePrice(DOUALA, {
      distanceMeters: 1_000,
      packageSize: 'S',
      isExpress: false,
      at: DAY,
    });
    expect(price.surcharges).toEqual([]);
    expect(price.totalPrice).toBe(1000);
  });

  it('annonce les frais d’échec : tentative fixe ou en part du prix de base, retour à 50 %', () => {
    const at7km = { distanceMeters: 7_000, packageSize: 'S' as const, isExpress: false, at: DAY };
    expect(computePrice(DOUALA, at7km)).toMatchObject({ retryFee: 750, returnFee: 750 });
    const grid: GridRules = {
      ...DOUALA,
      surcharges: [
        { code: 'FAILED_ATTEMPT', amount: 500, percentBps: null, active: true },
        { code: 'RETURN', amount: null, percentBps: 5000, active: true },
      ],
    };
    expect(computePrice(grid, at7km)).toMatchObject({ retryFee: 500, returnFee: 750 });
    // Frais désactivés dans la grille : rien à payer en cas d'échec.
    const none: GridRules = { ...DOUALA, surcharges: [] };
    expect(computePrice(none, at7km)).toMatchObject({ retryFee: 0, returnFee: 0 });
  });

  it('calcule un supplément en pourcentage du prix de base', () => {
    const grid: GridRules = {
      ...DOUALA,
      surcharges: [{ code: 'EXPRESS', amount: null, percentBps: 2500, active: true }],
    };
    const price = computePrice(grid, {
      distanceMeters: 7_000,
      packageSize: 'S',
      isExpress: true,
      at: DAY,
    });
    expect(price.surcharges).toEqual([{ code: 'EXPRESS', amount: 375 }]);
  });

  it('fait financer la promotion par Tara : la part du livreur ne baisse pas', () => {
    const price = computePrice(DOUALA, {
      distanceMeters: 7_000,
      packageSize: 'M',
      isExpress: false,
      at: DAY,
      promo: { kind: 'FIXED_PRICE', value: 500 },
    });
    expect(price).toMatchObject({
      discountTotal: 1000,
      totalPrice: 500,
      riderEarning: 1200,
      platformFee: -700,
    });
  });
});

describe('remises', () => {
  it.each([
    ['FIXED_AMOUNT', 300, 1500, 300],
    ['FIXED_AMOUNT', 3000, 1500, 1500],
    ['PERCENT', 2000, 1500, 300],
    ['PERCENT', 15_000, 1500, 1500],
    ['FIXED_PRICE', 500, 1500, 1000],
    ['FIXED_PRICE', 2000, 1500, 0],
  ] as const)('%s %i sur %i FCFA → %i FCFA de remise', (kind, value, subtotal, discount) => {
    expect(discountFor({ kind, value }, subtotal)).toBe(discount);
  });
});

describe('gros objets (tricycle)', () => {
  const TRICYCLE: GridRules = {
    riderShareBps: 8000,
    perKmBeyondLastTier: 300,
    tiers: [
      { upToMeters: 5_000, price: 3000 },
      { upToMeters: 10_000, price: 4500 },
      { upToMeters: 15_000, price: 6000 },
    ],
    surcharges: [
      { code: 'HANDLING', amount: 1500, percentBps: null, active: true },
      { code: 'FAILED_ATTEMPT', amount: 1500, percentBps: null, active: true },
      { code: 'RETURN', amount: null, percentBps: 5000, active: true },
    ],
  };

  it('ajoute la manutention seulement si l’aide au chargement est demandée', () => {
    const base = {
      distanceMeters: 7_000,
      packageSize: 'BULKY' as const,
      isExpress: false,
      at: DAY,
    };
    expect(computePrice(TRICYCLE, base)).toMatchObject({
      basePrice: 4500,
      surchargesTotal: 0,
      totalPrice: 4500,
    });
    expect(computePrice(TRICYCLE, { ...base, loadingHelp: true })).toMatchObject({
      surcharges: [{ code: 'HANDLING', amount: 1500 }],
      totalPrice: 6000,
      riderEarning: 4800,
      platformFee: 1200,
      retryFee: 1500,
      returnFee: 2250,
    });
    // Pas de manutention pour un colis ordinaire, même demandée par erreur.
    expect(
      computePrice(TRICYCLE, { ...base, packageSize: 'L', loadingHelp: true }).surchargesTotal,
    ).toBe(0);
  });

  it('choisit le véhicule selon le colis et refuse un gros objet sur une moto', () => {
    expect(vehicleForParcel('XL')).toBe('MOTORBIKE');
    expect(vehicleForParcel('BULKY')).toBe('TRICYCLE');
    expect(vehicleCarries('MOTORBIKE', 'BULKY')).toBe(false);
    expect(vehicleCarries('TRICYCLE', 'BULKY')).toBe(true);
    expect(vehicleCarries('CAR', 'BULKY')).toBe(true);
    expect(vehicleCarries('MOTORBIKE', 'XL')).toBe(true);
  });
});

describe('tarif pro et primes des livreurs (H4)', () => {
  const at = DAY;
  it('prend le tarif pro sur la part de Tara, arrondi à 50 F', () => {
    const price = computePrice(DOUALA, {
      distanceMeters: 7_000,
      packageSize: 'M',
      isExpress: false,
      at,
      volumeDiscountBps: 1000,
    });
    // 10 % de 1 500 = 150 F ; le livreur garde sa part entière.
    expect(price).toMatchObject({
      discountTotal: 150,
      discountSource: 'VOLUME',
      proDiscountBps: 1000,
      totalPrice: 1350,
      riderEarning: 1200,
      platformFee: 150,
    });
    // 15 % de 1 450 = 217,5 F, arrondi à 200 F : le total se paie avec des pièces de 50 F.
    const rounded = computePrice(
      { ...DOUALA, tiers: [{ upToMeters: 5_000, price: 1450 }] },
      { distanceMeters: 1_000, packageSize: 'S', isExpress: false, at, volumeDiscountBps: 1500 },
    );
    expect(rounded).toMatchObject({ discountTotal: 200, totalPrice: 1250 });
  });

  it('retient le plus avantageux du code promo et du tarif pro, jamais les deux', () => {
    const input = { distanceMeters: 7_000, packageSize: 'M' as const, isExpress: false, at };
    expect(
      computePrice(DOUALA, {
        ...input,
        volumeDiscountBps: 1000,
        promo: { kind: 'FIXED_AMOUNT', value: 500 },
      }),
    ).toMatchObject({ discountTotal: 500, discountSource: 'PROMO', proDiscountBps: 0 });
    expect(
      computePrice(DOUALA, {
        ...input,
        volumeDiscountBps: 1500,
        promo: { kind: 'FIXED_AMOUNT', value: 100 },
      }),
    ).toMatchObject({ discountTotal: 250, discountSource: 'VOLUME', proDiscountBps: 1500 });
  });

  it('choisit le palier atteint par les livraisons du mois', () => {
    const tiers = [
      { fromDeliveries: 100, percentBps: 1000 },
      { fromDeliveries: 300, percentBps: 1500 },
    ];
    expect(volumeDiscountFor(tiers, 99)).toBe(0);
    expect(volumeDiscountFor(tiers, 100)).toBe(1000);
    expect(volumeDiscountFor(tiers, 450)).toBe(1500);
  });

  it('verse la prime d’approche au-delà du seuil seulement', () => {
    const settings = { approachBonusAmount: 200, approachBonusFromMeters: 3000 };
    expect(approachBonusFor(settings, 2_900)).toBe(0);
    expect(approachBonusFor(settings, 3_400)).toBe(200);
    expect(approachBonusFor(settings, null)).toBe(0);
  });
});

describe('garantie de la valeur déclarée', () => {
  it.each([
    [undefined, 0],
    [null, 0],
    [25_000, 0],
    [26_000, 50],
    [30_000, 50],
    [100_000, 750],
    [150_000, 1250],
    [500_000, 4750],
  ])('%s F déclarés → %i F de garantie', (value, fee) => {
    expect(valueFeeFor(value)).toBe(fee);
  });

  it('s’ajoute au total, tout pour Tara, sans remise possible', () => {
    const price = computePrice(DOUALA, {
      distanceMeters: 7_000,
      packageSize: 'M',
      isExpress: false,
      at: DAY,
      promo: { kind: 'FIXED_PRICE', value: 500 },
      declaredValue: 150_000,
    });
    expect(price).toMatchObject({
      subtotal: 1500,
      discountTotal: 1000,
      valueFee: 1250,
      totalPrice: 1750,
      riderEarning: 1200,
      platformFee: 550,
    });
  });
});
