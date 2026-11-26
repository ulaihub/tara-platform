import { Pills } from '@/components/pills';
import { TopBar } from '@/components/top-bar';

const TABS = [
  { href: '/marchands', label: 'Boutiques', title: 'Boutiques' },
  { href: '/marchands/tarifs', label: 'Tarifs et primes', title: 'Tarifs et primes' },
  { href: '/marchands/promotions', label: 'Codes promo', title: 'Codes promo' },
  { href: '/marchands/zones', label: 'Zones', title: 'Zones' },
  { href: '/marchands/reperes', label: 'Repères', title: 'Repères de la carte' },
] as const;

/**
 * En-tête commun des pages « Boutiques, tarifs et zones » (H4, maquettes BO-Boutiques et
 * BO-Tarifs) : barre du haut, puis les quatre pages en pastilles.
 */
export function MerchantsHeader({
  current,
  aside,
}: {
  current: (typeof TABS)[number]['href'];
  aside?: string;
}) {
  const tab = TABS.find((item) => item.href === current) ?? TABS[0];
  return (
    <>
      <TopBar title={tab.title} subtitle={aside ?? 'Boutiques, tarifs, promotions et zones'} />
      <Pills
        label="Boutiques, tarifs et zones"
        items={TABS.map((item) => ({
          href: item.href,
          label: item.label,
          active: item.href === current,
        }))}
      />
    </>
  );
}
