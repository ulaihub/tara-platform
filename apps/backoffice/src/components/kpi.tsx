import { cx } from './ui';

/** Chiffre-clé (maquettes BO) : carte de verre, libellé, chiffre en grand, note, barre. */
export function Kpi({
  label,
  value,
  note,
  tone,
  fill = null,
}: {
  label: string;
  value: string;
  note: string | null;
  tone: 'up' | 'down' | 'accent';
  fill?: number | null;
}) {
  return (
    <div className="bo-glass flex flex-col gap-1.5 rounded-[22px] px-[18px] py-4">
      <span className="text-[12px] font-bold text-muted">{label}</span>
      <b className="font-display text-[26px] leading-tight tracking-[-0.02em]">{value}</b>
      <span
        className={cx(
          'min-h-[18px] text-[12px] font-extrabold',
          tone === 'up' && 'text-ok',
          tone === 'down' && 'text-danger',
          tone === 'accent' && 'text-accent',
        )}
      >
        {note}
      </span>
      {fill === null ? null : <Fill value={fill} />}
    </div>
  );
}

/** Barre qui coule (maquette) : en SVG, la page n'accepte pas de style en ligne. */
function Fill({ value }: { value: number }) {
  const width = `${Math.round(Math.max(0, Math.min(1, value)) * 100)}%`;
  return (
    <svg className="h-1.5 w-full overflow-hidden rounded-[3px]" aria-hidden="true">
      <defs>
        <linearGradient
          id="bo-flow"
          x1="0"
          x2="200"
          gradientUnits="userSpaceOnUse"
          spreadMethod="repeat"
        >
          <stop offset="0" stopColor="#FFB000" />
          <stop offset=".25" stopColor="#FF6A00" />
          <stop offset=".5" stopColor="#FF3D00" />
          <stop offset=".75" stopColor="#FF6A00" />
          <stop offset="1" stopColor="#FFB000" />
          <animateTransform
            attributeName="gradientTransform"
            type="translate"
            from="0 0"
            to="-200 0"
            dur="2.6s"
            repeatCount="indefinite"
          />
        </linearGradient>
      </defs>
      <rect width="100%" height="6" className="fill-track" />
      <rect width={width} height="6" rx="3" fill="url(#bo-flow)" />
    </svg>
  );
}
