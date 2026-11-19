import { stopOrder, tourMembers, tourMeters } from './tour.js';

const parcel = (id: string, packageSize: 'S' | 'M' | 'L' | 'XL' | 'BULKY') => ({ id, packageSize });

describe('tournée : quels colis partent ensemble', () => {
  const smalls = ['a', 'b', 'c', 'd', 'e', 'f'].map((id) => parcel(id, 'S'));

  it('une moto : 5 petits ou moyens colis en tout', () => {
    expect(tourMembers(parcel('lead', 'M'), smalls, 5).map((p) => p.id)).toEqual([
      'a',
      'b',
      'c',
      'd',
    ]);
  });

  it('un grand colis part seul', () => {
    expect(tourMembers(parcel('lead', 'XL'), smalls, 5)).toEqual([]);
    expect(tourMembers(parcel('lead', 'L'), smalls, 5)).toEqual([]);
  });

  it('un gros objet emmène des petits colis, jamais un autre grand', () => {
    const mixed = [parcel('x', 'XL'), parcel('g', 'BULKY'), ...smalls];
    expect(tourMembers(parcel('frigo', 'BULKY'), mixed, 5)).toHaveLength(5);
    expect(tourMembers(parcel('frigo', 'BULKY'), mixed, 5).map((p) => p.packageSize)).toEqual(
      Array(5).fill('S'),
    );
  });
});

describe('tournée : ordre des arrêts', () => {
  const pickup = { latitude: 4.05, longitude: 9.7 };
  const at = (id: string, km: number) => ({
    id,
    dropoff: { latitude: 4.05 + km / 111, longitude: 9.7 },
  });

  it('le client le plus proche d’abord, puis de proche en proche', () => {
    const ordered = stopOrder(pickup, [at('far', 6), at('near', 1), at('mid', 3)]);
    expect(ordered.map((stop) => stop.id)).toEqual(['near', 'mid', 'far']);
  });

  it('longueur estimée du trajet, rues comprises', () => {
    const meters = tourMeters(pickup, [at('a', 1), at('b', 3)]);
    expect(meters).toBeGreaterThan(3_800);
    expect(meters).toBeLessThan(4_100);
  });
});
