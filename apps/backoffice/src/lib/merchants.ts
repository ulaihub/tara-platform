import type { StaffRole } from './session';
import type { PricingGrid, RiderBoost, Schemas } from './schemas';

/** Marchands et tarifs (H4) : réservé aux administrateurs, comme l'API des tarifs. */
export const PRICING_ROLES: readonly StaffRole[] = ['ADMIN'];

/** Pourcentage lisible depuis des points de base : 1000 → « 10 % », 1250 → « 12,5 % ». */
export function percent(bps: number): string {
  const value = bps % 100 === 0 ? String(bps / 100) : (bps / 100).toFixed(1).replace('.', ',');
  return `${value} %`;
}

/** Distance lisible : 16 800 → « 16,8 km », 5 000 → « 5 km ». */
export function km(meters: number): string {
  const value = meters / 1000;
  return `${Number.isInteger(value) ? value : value.toFixed(1).replace('.', ',')} km`;
}

/**
 * Trajets de Douala mesurés par la route (centre de quartier à centre de quartier) : ils
 * servent d'exemples parlants pour juger une grille avant de l'enregistrer.
 */
export const EXAMPLE_TRIPS: readonly { label: string; meters: number }[] = [
  { label: 'Course courte dans le quartier', meters: 3000 },
  { label: 'Bonapriso → Bonabéri', meters: 11_300 },
  { label: 'Bonapriso → Logbessou', meters: 16_800 },
  { label: 'Logbessou → Bonabéri', meters: 17_200 },
  { label: 'Bonabéri → Yassa', meters: 28_400 },
];

/**
 * Grille « simple », telle que l'équipe la pense : un prix de départ jusqu'à une distance,
 * puis un prix par km jusqu'à une seconde distance, puis un prix par km au-delà.
 */
export interface SimpleGrid {
  startPrice: number;
  startKm: number;
  stepPrice: number;
  untilKm: number;
  beyondPerKm: number;
  riderSharePercent: number;
}

/** Paliers d'un km correspondant à une grille simple (le moteur facture le km commencé). */
export function tiersFor(grid: SimpleGrid): { upToMeters: number; price: number }[] {
  const tiers = [{ upToMeters: grid.startKm * 1000, price: grid.startPrice }];
  for (let k = grid.startKm + 1; k <= grid.untilKm; k += 1) {
    tiers.push({
      upToMeters: k * 1000,
      price: grid.startPrice + (k - grid.startKm) * grid.stepPrice,
    });
  }
  return tiers;
}

/** Relit une grille enregistrée comme grille simple ; null si elle a une autre forme. */
export function simpleGridOf(
  grid: Pick<PricingGrid, 'tiers' | 'perKmBeyondLastTier' | 'riderShareBps'>,
): SimpleGrid | null {
  const tiers = [...grid.tiers].sort((a, b) => a.upToMeters - b.upToMeters);
  const first = tiers[0];
  if (!first || first.upToMeters % 1000 !== 0) return null;
  const startKm = first.upToMeters / 1000;
  const rest = tiers.slice(1);
  const second = rest[0];
  const stepPrice = second ? second.price - first.price : 0;
  const regular = rest.every(
    (tier, index) =>
      tier.upToMeters === (startKm + index + 1) * 1000 &&
      tier.price === first.price + (index + 1) * stepPrice,
  );
  if (!regular) return null;
  return {
    startPrice: first.price,
    startKm,
    stepPrice,
    untilKm: startKm + rest.length,
    beyondPerKm: grid.perKmBeyondLastTier,
    riderSharePercent: grid.riderShareBps / 100,
  };
}

/**
 * Point de départ de l'éditeur : la grille simple elle-même, sinon son équivalent aux
 * mêmes distances (ex. tricycle : 3 000 F à 5 km, 4 500 F à 10 km → +300 F par km).
 */
export function editableGridOf(
  grid: Pick<PricingGrid, 'tiers' | 'perKmBeyondLastTier' | 'riderShareBps'>,
): SimpleGrid {
  const simple = simpleGridOf(grid);
  if (simple) return simple;
  const tiers = [...grid.tiers].sort((a, b) => a.upToMeters - b.upToMeters);
  const first = tiers[0] ?? { upToMeters: 5000, price: 1000 };
  const second = tiers[1];
  const startKm = Math.max(1, Math.round(first.upToMeters / 1000));
  const untilKm = second ? Math.max(startKm, Math.round(second.upToMeters / 1000)) : startKm;
  const perKm =
    second && untilKm > startKm ? (second.price - first.price) / (untilKm - startKm) : 0;
  return {
    startPrice: first.price,
    startKm,
    stepPrice: Math.round(perKm / 50) * 50,
    untilKm,
    beyondPerKm: grid.perKmBeyondLastTier,
    riderSharePercent: grid.riderShareBps / 100,
  };
}

/** Phrase qui décrit une grille simple, pour l'équipe. */
export function describeGrid(grid: SimpleGrid): string {
  const money = (value: number) => `${value.toLocaleString('fr-FR')} F`;
  const start = `${money(grid.startPrice)} jusqu’à ${grid.startKm} km`;
  const step =
    grid.untilKm > grid.startKm
      ? `, +${money(grid.stepPrice)} par km jusqu’à ${grid.untilKm} km`
      : '';
  return `${start}${step}, puis +${money(grid.beyondPerKm)} par km.`;
}

/** Vérifie une grille simple avant de l'envoyer ; renvoie le problème, sinon null. */
export function gridProblem(grid: SimpleGrid): string | null {
  const values = Object.values(grid);
  if (values.some((value) => !Number.isFinite(value) || value < 0)) {
    return 'Tous les montants doivent être des nombres positifs.';
  }
  if (grid.startPrice < 100) return 'Le prix de départ doit être d’au moins 100 F.';
  if (grid.startKm < 1 || grid.startKm > 30) return 'La première distance va de 1 à 30 km.';
  if (grid.untilKm < grid.startKm || grid.untilKm - grid.startKm > 18) {
    return 'La seconde distance suit la première, 18 km plus loin au plus.';
  }
  if (grid.riderSharePercent < 50 || grid.riderSharePercent > 95) {
    return 'La part du livreur va de 50 à 95 %.';
  }
  if ([grid.startPrice, grid.stepPrice, grid.beyondPerKm].some((value) => value % 50 !== 0)) {
    return 'Les montants vont de 50 F en 50 F, pour rendre la monnaie facilement.';
  }
  return null;
}

type SurchargeCode = Schemas['SurchargeCode'];

export const SURCHARGE_LABELS: Record<SurchargeCode, { label: string; hint: string }> = {
  EXPRESS: { label: 'Express', hint: 'Livraison en priorité, choisie par l’expéditeur.' },
  HEAVY_PARCEL: { label: 'Colis XL', hint: 'Jusqu’à 20 kg, à moto.' },
  NIGHT: { label: 'Nuit', hint: 'De 20 h à 6 h.' },
  WEATHER: { label: 'Forte pluie', hint: 'À activer pendant les grosses pluies.' },
  HANDLING: { label: 'Manutention', hint: 'Gros objet : deux personnes pour charger.' },
  FAILED_ATTEMPT: { label: 'Nouvelle tentative', hint: 'Seulement si la livraison échoue.' },
  RETURN: { label: 'Retour à l’expéditeur', hint: 'Seulement si le colis revient.' },
};

export const BOOST_STATUS: Record<RiderBoost['status'], { label: string; tone: string }> = {
  ACTIVE: { label: 'En cours', tone: 'bg-ok-bg text-ok' },
  SCHEDULED: { label: 'Prévue', tone: 'bg-warn-bg text-warn' },
  ENDED: { label: 'Terminée', tone: 'bg-track text-muted' },
  CANCELLED: { label: 'Arrêtée', tone: 'bg-track text-muted' },
};

export const ZONE_KIND_LABELS: Record<Schemas['ZoneKind'], string> = {
  SERVICE_AREA: 'Zone desservie',
  NEIGHBORHOOD: 'Quartier',
  NO_MOTORBIKE: 'Interdite aux motos',
};

export const PROMO_KIND_LABELS: Record<Schemas['PromoKind'], string> = {
  FIXED_AMOUNT: 'Montant déduit',
  PERCENT: 'Pourcentage',
  FIXED_PRICE: 'Prix fixe',
};

/** Valeur d'un code promo, lisible. */
export function promoValue(kind: Schemas['PromoKind'], value: number): string {
  if (kind === 'PERCENT') return `−${percent(value)}`;
  const money = `${value.toLocaleString('fr-FR')} F`;
  return kind === 'FIXED_AMOUNT' ? `−${money}` : `course à ${money}`;
}
