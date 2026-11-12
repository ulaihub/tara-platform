'use server';

import { revalidatePath } from 'next/cache';
import { ApiError } from '@/lib/api';
import { requireStaff, staffApi } from '@/lib/dal';
import { gridProblem, PRICING_ROLES, type SimpleGrid, tiersFor } from '@/lib/merchants';
import type { PriceSimulation, PricingGrid } from '@/lib/schemas';

/** Résultat d'une action, affiché sous le bouton. */
export interface ActionState {
  error: string | null;
  done: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function field(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

function int(form: FormData, name: string): number {
  const raw = field(form, name).replace(/\s/g, '').replace(',', '.');
  return raw === '' ? Number.NaN : Number(raw);
}

function failure(error: unknown): ActionState {
  if (error instanceof ApiError) return { error: error.message, done: false };
  return { error: 'Action impossible pour le moment, réessayez.', done: false };
}

function gridFrom(form: FormData): SimpleGrid {
  return {
    startPrice: int(form, 'startPrice'),
    startKm: int(form, 'startKm'),
    stepPrice: int(form, 'stepPrice'),
    untilKm: int(form, 'untilKm'),
    beyondPerKm: int(form, 'beyondPerKm'),
    riderSharePercent: int(form, 'riderSharePercent'),
  };
}

/** Prix de la grille en projet pour les trajets d'exemple, calculés par le serveur. */
export async function simulateGrid(
  grid: SimpleGrid,
  distancesMeters: number[],
): Promise<PriceSimulation['rows'] | { error: string }> {
  await requireStaff(PRICING_ROLES);
  const problem = gridProblem(grid);
  if (problem) return { error: problem };
  try {
    const result = await staffApi<PriceSimulation>('/admin/pricing-grids/simulate', {
      method: 'POST',
      body: {
        riderShareBps: Math.round(grid.riderSharePercent * 100),
        perKmBeyondLastTier: grid.beyondPerKm,
        tiers: tiersFor(grid),
        distancesMeters,
      },
    });
    return result.rows;
  } catch (error) {
    return { error: failure(error).error ?? 'Calcul impossible.' };
  }
}

/**
 * Nouvelle version de la grille, activée tout de suite : les commandes suivantes l'utilisent,
 * les commandes passées gardent leur prix. Les suppléments de la grille actuelle sont repris.
 */
export async function saveGrid(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const currentId = field(form, 'currentId');
  if (!UUID.test(currentId)) return { error: 'Grille actuelle inconnue.', done: false };
  const grid = gridFrom(form);
  const problem = gridProblem(grid);
  if (problem) return { error: problem, done: false };
  try {
    const grids = await staffApi<PricingGrid[]>('/admin/pricing-grids');
    const current = grids.find((item) => item.id === currentId);
    if (!current) return { error: 'Grille actuelle introuvable.', done: false };
    const date = new Intl.DateTimeFormat('fr-FR', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      timeZone: 'Africa/Douala',
    }).format(new Date());
    await staffApi('/admin/pricing-grids', {
      method: 'POST',
      body: {
        name: `${current.city} ${current.vehicleType === 'TRICYCLE' ? 'tricycle' : 'moto'} — ${date}`,
        city: current.city,
        vehicleType: current.vehicleType,
        riderShareBps: Math.round(grid.riderSharePercent * 100),
        perKmBeyondLastTier: grid.beyondPerKm,
        tiers: tiersFor(grid),
        surcharges: current.surcharges.map((s) => ({
          code: s.code,
          ...(s.amount === null ? {} : { amount: s.amount }),
          ...(s.percentBps === null ? {} : { percentBps: s.percentBps }),
          active: s.active,
        })),
        // Une grille pas encore ouverte (gros objets) le reste : enregistrer n'ouvre rien.
        activate: current.active,
      },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/marchands/tarifs');
  return { error: null, done: true };
}

/** Active ou coupe un supplément (pluie forte, nuit…) sans nouvelle version de grille. */
export async function toggleSurcharge(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const gridId = field(form, 'gridId');
  const code = field(form, 'code');
  if (!UUID.test(gridId) || !/^[A-Z_]{3,20}$/.test(code)) {
    return { error: 'Supplément inconnu.', done: false };
  }
  try {
    await staffApi(`/admin/pricing-grids/${gridId}/surcharges/${code}`, {
      method: 'PATCH',
      body: { active: field(form, 'active') === 'true' },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/marchands/tarifs');
  return { error: null, done: true };
}

/** Tarif pro des boutiques et prime d'approche des livreurs. */
export async function saveSettings(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const tiers: { fromDeliveries: number; percentBps: number }[] = [];
  for (const index of [0, 1, 2]) {
    const from = int(form, `from${index}`);
    const pct = int(form, `percent${index}`);
    if (Number.isNaN(from) && Number.isNaN(pct)) continue;
    if (!Number.isInteger(from) || from < 1 || !(pct > 0) || pct > 50) {
      return {
        error: 'Chaque palier : un nombre de livraisons et une remise de 1 à 50 %.',
        done: false,
      };
    }
    tiers.push({ fromDeliveries: from, percentBps: Math.round(pct * 100) });
  }
  const amount = int(form, 'approachBonusAmount');
  const fromKm = int(form, 'approachBonusFromKm');
  if (!Number.isInteger(amount) || amount < 0 || amount % 50 !== 0) {
    return { error: 'La prime d’approche va de 50 F en 50 F (0 pour la couper).', done: false };
  }
  if (!(fromKm >= 0) || fromKm > 20) {
    return { error: 'La distance de la prime d’approche va de 0 à 20 km.', done: false };
  }
  try {
    await staffApi('/admin/pricing-settings/Douala', {
      method: 'PUT',
      body: {
        volumeDiscounts: tiers,
        approachBonusAmount: amount,
        approachBonusFromMeters: Math.round(fromKm * 1000),
      },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/marchands/tarifs');
  revalidatePath('/marchands');
  return { error: null, done: true };
}

/** Prime de renfort pour les courses proposées pendant la période (pluie, heures de pointe). */
export async function createBoost(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const amount = int(form, 'amount');
  const hours = int(form, 'hours');
  const reason = field(form, 'reason');
  if (!Number.isInteger(amount) || amount < 50 || amount > 5000 || amount % 50 !== 0) {
    return { error: 'Montant de 50 à 5 000 F, de 50 F en 50 F.', done: false };
  }
  if (!(hours >= 1 && hours <= 12)) return { error: 'Durée de 1 à 12 heures.', done: false };
  if (reason.length < 3) return { error: 'Indiquez la raison (ex. forte pluie).', done: false };
  try {
    await staffApi('/admin/rider-boosts', {
      method: 'POST',
      body: {
        city: 'Douala',
        amount,
        reason,
        endsAt: new Date(Date.now() + hours * 3_600_000).toISOString(),
      },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/marchands/tarifs');
  return { error: null, done: true };
}

export async function cancelBoost(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const id = field(form, 'boostId');
  if (!UUID.test(id)) return { error: 'Prime inconnue.', done: false };
  try {
    await staffApi(`/admin/rider-boosts/${id}/cancel`, { method: 'POST' });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/marchands/tarifs');
  return { error: null, done: true };
}

/** Nouveau code promo, financé par Tara (la part du livreur ne baisse pas). */
export async function createPromo(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const code = field(form, 'code').toUpperCase();
  const kind = field(form, 'kind');
  const raw = int(form, 'value');
  const days = int(form, 'days');
  const max = int(form, 'maxRedemptions');
  if (!/^[A-Z0-9-]{3,32}$/.test(code)) {
    return { error: 'Le code : lettres, chiffres et tirets, 3 à 32 caractères.', done: false };
  }
  if (!['FIXED_AMOUNT', 'PERCENT', 'FIXED_PRICE'].includes(kind)) {
    return { error: 'Choisissez le type de remise.', done: false };
  }
  if (!(raw > 0) || (kind === 'PERCENT' && raw > 100)) {
    return { error: 'Indiquez la valeur de la remise.', done: false };
  }
  try {
    await staffApi('/admin/promo-codes', {
      method: 'POST',
      body: {
        code,
        kind,
        value: kind === 'PERCENT' ? Math.round(raw * 100) : Math.round(raw),
        perUserLimit: 1,
        newCustomersOnly: field(form, 'newCustomersOnly') === 'on',
        ...(Number.isInteger(max) && max > 0 ? { maxRedemptions: max } : {}),
        ...(Number.isInteger(days) && days > 0
          ? { validTo: new Date(Date.now() + days * 86_400_000).toISOString() }
          : {}),
      },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/marchands/promotions');
  return { error: null, done: true };
}

export async function togglePromo(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const id = field(form, 'promoId');
  if (!UUID.test(id)) return { error: 'Code inconnu.', done: false };
  try {
    await staffApi(`/admin/promo-codes/${id}`, {
      method: 'PATCH',
      body: { active: field(form, 'active') === 'true' },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/marchands/promotions');
  return { error: null, done: true };
}

/** Coupe ou rétablit une zone (zone desservie, interdite aux motos, quartier). */
export async function toggleZone(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const id = field(form, 'zoneId');
  if (!UUID.test(id)) return { error: 'Zone inconnue.', done: false };
  try {
    await staffApi(`/admin/zones/${id}`, {
      method: 'PATCH',
      body: { active: field(form, 'active') === 'true' },
    });
  } catch (error) {
    return failure(error);
  }
  revalidatePath('/marchands/zones');
  return { error: null, done: true };
}

const ZONE_KINDS = ['SERVICE_AREA', 'NO_MOTORBIKE', 'NEIGHBORHOOD'];

/** Zone dessinée sur la carte : polygone fermé, vérifié par le serveur avant d'être gardé. */
export async function createZone(_: ActionState, form: FormData): Promise<ActionState> {
  await requireStaff(PRICING_ROLES);
  const name = field(form, 'name');
  const kind = field(form, 'kind');
  let points: unknown;
  try {
    points = JSON.parse(field(form, 'points') || '[]');
  } catch {
    points = [];
  }
  const ring = Array.isArray(points)
    ? points.filter(
        (point): point is [number, number] =>
          Array.isArray(point) &&
          point.length === 2 &&
          point.every((value) => typeof value === 'number' && Number.isFinite(value)) &&
          Math.abs(point[0]) <= 180 &&
          Math.abs(point[1]) <= 90,
      )
    : [];
  if (name.length < 2) return { error: 'Donnez un nom à la zone.', done: false };
  if (!ZONE_KINDS.includes(kind)) return { error: 'Choisissez le type de zone.', done: false };
  if (ring.length < 3 || ring.length > 200) {
    return { error: 'Placez au moins 3 points sur la carte.', done: false };
  }
  try {
    await staffApi('/admin/zones', {
      method: 'POST',
      body: {
        name,
        city: 'Douala',
        kind,
        geometry: { type: 'Polygon', coordinates: [[...ring, ring[0]]] },
      },
    });
  } catch (error) {
    if (error instanceof ApiError && error.code === 'ZONE_GEOMETRY_INVALID') {
      return {
        error: 'Le contour se croise : replacez les points dans l’ordre, en faisant le tour.',
        done: false,
      };
    }
    return failure(error);
  }
  revalidatePath('/marchands/zones');
  return { error: null, done: true };
}
