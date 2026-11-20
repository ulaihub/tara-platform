import { Pills } from './pills';
import { TopBar } from './top-bar';

export interface SectionTab {
  href: string;
  label: string;
  /** Titre de la barre du haut sur cette page, et sous-titre par défaut. */
  title: string;
  subtitle: string;
}

/** En-tête des sections à plusieurs pages (maquettes BO) : barre du haut puis pastilles. */
export function SectionHeader({
  tabs,
  current,
  label,
  aside,
}: {
  tabs: readonly SectionTab[];
  current: string;
  label: string;
  aside?: string;
}) {
  const tab = tabs.find((item) => item.href === current) ?? tabs[0];
  return (
    <>
      <TopBar
        title={tab?.title ?? label}
        subtitle={[tab?.subtitle, aside].filter(Boolean).join(' · ')}
      />
      <Pills
        label={label}
        items={tabs.map((item) => ({
          href: item.href,
          label: item.label,
          active: item.href === current,
        }))}
      />
    </>
  );
}
