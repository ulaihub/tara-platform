import type { Metadata } from 'next';
import { requireStaff, staffApi } from '@/lib/dal';
import { PRICING_ROLES, ZONE_KIND_LABELS } from '@/lib/merchants';
import type { AdminZonesMap, Zone } from '@/lib/schemas';
import { ZoneToggle } from '../row-actions';
import { MerchantsHeader } from '../tabs';
import { ZoneMap } from './zone-map';

export const metadata: Metadata = { title: 'Zones' };

const ORDER: Zone['kind'][] = ['SERVICE_AREA', 'NO_MOTORBIKE', 'NEIGHBORHOOD'];
const HINTS: Record<Zone['kind'], string> = {
  SERVICE_AREA: 'Hors de ces zones, les commandes sont refusées.',
  NO_MOTORBIKE: 'Les motos n’y entrent pas : la carte des livreurs les montre.',
  NEIGHBORHOOD: 'Quartiers proposés aux clients pour situer une adresse.',
};

/** Zones (B6, H4) : zone desservie, zones interdites aux motos, quartiers ; coupées ou actives. */
export default async function ZonesPage() {
  await requireStaff(PRICING_ROLES);
  const [zones, map] = await Promise.all([
    staffApi<Zone[]>('/admin/zones', { query: { city: 'Douala' } }),
    staffApi<AdminZonesMap>('/admin/zones/map', { query: { city: 'Douala' } }),
  ]);

  return (
    <div className="mx-auto max-w-[1280px]">
      <MerchantsHeader
        current="/marchands/zones"
        aside="Couper une zone l’enlève tout de suite des apps ; la rétablir la remet."
      />
      <section className="mb-5 rounded-3xl border border-line bg-panel p-5 shadow-card">
        <h2 className="mb-3 font-display text-[17px] font-bold">Carte des zones</h2>
        <ZoneMap zones={map} />
      </section>
      <div className="space-y-5">
        {ORDER.map((kind) => {
          const items = zones.filter((zone) => zone.kind === kind);
          if (items.length === 0) return null;
          return (
            <section key={kind} className="rounded-3xl border border-line bg-panel p-5 shadow-card">
              <h2 className="font-display text-[17px] font-bold">
                {ZONE_KIND_LABELS[kind]}{' '}
                <span className="text-[14px] font-semibold text-muted">({items.length})</span>
              </h2>
              <p className="mb-3 text-[13px] text-muted">{HINTS[kind]}</p>
              <ul className="grid gap-x-6 divide-y divide-line md:grid-cols-2 md:divide-y-0">
                {items.map((zone) => (
                  <li
                    key={zone.id}
                    className="flex items-center gap-3 border-line py-2 md:border-b"
                  >
                    <span className="flex-1 text-[14px] font-semibold">{zone.name}</span>
                    <ZoneToggle id={zone.id} active={zone.active} />
                  </li>
                ))}
              </ul>
            </section>
          );
        })}
      </div>
    </div>
  );
}
