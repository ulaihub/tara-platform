'use client';

import { useState } from 'react';
import { longDate } from '@/lib/douala';
import { ticks } from '@/lib/metrics';
import type { Metrics } from '@/lib/schemas';

type Day = Metrics['daily'][number];

const WIDTH = 760;
const HEIGHT = 220;
const LEFT = 36;
const BOTTOM = 26;
const TOP = 12;
const label = (day: string) => longDate.format(new Date(`${day}T12:00:00Z`));
const short = (day: string) =>
  new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', timeZone: 'UTC' }).format(
    new Date(`${day}T12:00:00Z`),
  );

/**
 * Livraisons réussies par jour : une seule série (pas de légende, le titre la nomme), barres
 * fines à bout arrondi posées sur la ligne de base, grille discrète, détail au survol.
 * Tout en SVG : la politique de sécurité du site refuse les styles écrits dans la page.
 */
export function DailyChart({ days }: { days: Day[] }) {
  const [active, setActive] = useState<number | null>(null);
  const max = Math.max(0, ...days.map((day) => day.delivered));
  const scale = ticks(max);
  const top = scale.at(-1) || 1;
  const plotWidth = WIDTH - LEFT;
  const plotHeight = HEIGHT - TOP - BOTTOM;
  const slot = plotWidth / Math.max(1, days.length);
  const bar = Math.max(3, Math.min(22, slot - 2));
  const y = (value: number) => TOP + plotHeight - (value / top) * plotHeight;
  const labelEvery = days.length <= 7 ? 1 : days.length <= 30 ? 5 : 15;
  const hovered = active === null ? null : days[active];

  return (
    <svg
      viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
      className="h-auto w-full"
      role="img"
      aria-label="Livraisons réussies par jour"
      onMouseLeave={() => setActive(null)}
    >
      {scale.map((value) => (
        <g key={value}>
          <line
            x1={LEFT}
            x2={WIDTH}
            y1={y(value)}
            y2={y(value)}
            className={value === 0 ? 'stroke-line' : 'stroke-line/60'}
            strokeWidth={1}
          />
          <text
            x={LEFT - 8}
            y={y(value) + 4}
            textAnchor="end"
            className="fill-faint text-[11px] tabular-nums"
          >
            {value}
          </text>
        </g>
      ))}
      {days.map((day, index) => {
        const x = LEFT + index * slot + (slot - bar) / 2;
        const height = Math.max(0, y(0) - y(day.delivered));
        const radius = Math.min(4, bar / 2, height);
        return (
          <g key={day.day}>
            {height > 0 ? (
              <path
                d={`M${x},${y(0)} V${y(0) - height + radius} Q${x},${y(0) - height} ${x + radius},${y(0) - height} H${x + bar - radius} Q${x + bar},${y(0) - height} ${x + bar},${y(0) - height + radius} V${y(0)} Z`}
                className={active === index ? 'fill-accent' : 'fill-accent/75'}
              />
            ) : null}
            {(index % labelEvery === 0 && days.length - 1 - index >= labelEvery / 2) ||
            index === days.length - 1 ? (
              <text
                x={index === days.length - 1 ? x + bar : index === 0 ? x : x + bar / 2}
                y={HEIGHT - 8}
                textAnchor={index === days.length - 1 ? 'end' : index === 0 ? 'start' : 'middle'}
                className="fill-faint text-[11px]"
              >
                {short(day.day)}
              </text>
            ) : null}
            {/* Zone de survol plus large que la barre. */}
            <rect
              x={LEFT + index * slot}
              y={TOP}
              width={slot}
              height={plotHeight}
              className="fill-transparent"
              onMouseEnter={() => setActive(index)}
              onFocus={() => setActive(index)}
              tabIndex={0}
              aria-label={`${label(day.day)} : ${day.delivered} livrées, ${day.failed} échecs, ${day.returned} retours, ${day.cancelled} annulées`}
            />
          </g>
        );
      })}
      {hovered && active !== null ? (
        <Tooltip
          day={hovered}
          x={Math.min(WIDTH - 190, Math.max(LEFT, LEFT + active * slot + slot / 2 - 95))}
          y={TOP}
        />
      ) : null}
    </svg>
  );
}

function Tooltip({ day, x, y }: { day: Day; x: number; y: number }) {
  const rows: [string, number][] = [
    ['Livrées', day.delivered],
    ['Échecs', day.failed],
    ['Retours', day.returned],
    ['Annulées', day.cancelled],
  ];
  return (
    <g pointerEvents="none">
      <rect x={x} y={y} width={190} height={106} rx={10} className="fill-panel stroke-line" />
      <text x={x + 12} y={y + 20} className="fill-text text-[12px] font-bold">
        {label(day.day)}
      </text>
      {rows.map(([name, value], index) => (
        <g key={name}>
          <text x={x + 12} y={y + 42 + index * 18} className="fill-muted text-[12px]">
            {name}
          </text>
          <text
            x={x + 178}
            y={y + 42 + index * 18}
            textAnchor="end"
            className="fill-text text-[12px] font-bold tabular-nums"
          >
            {value}
          </text>
        </g>
      ))}
    </g>
  );
}
