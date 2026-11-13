/** Heure et date de Douala (UTC+1, sans heure d'été), quel que soit le serveur. */
const TIME_ZONE = 'Africa/Douala';

const hourParts = new Intl.DateTimeFormat('fr-FR', {
  hour: 'numeric',
  hourCycle: 'h23',
  timeZone: TIME_ZONE,
});

export const longDate = new Intl.DateTimeFormat('fr-FR', {
  weekday: 'long',
  day: 'numeric',
  month: 'long',
  timeZone: TIME_ZONE,
});

/** Heure de Douala, de 0 à 23. */
export function doualaHour(now: Date): number {
  const hour = hourParts.formatToParts(now).find((part) => part.type === 'hour')?.value;
  return Number(hour ?? 0);
}

/** « Bonjour » de 5 h à 18 h, « Bonsoir » ensuite. */
export function greeting(now: Date): string {
  const hour = doualaHour(now);
  return hour >= 5 && hour < 18 ? 'Bonjour' : 'Bonsoir';
}

const dayParts = new Intl.DateTimeFormat('en-CA', {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  timeZone: TIME_ZONE,
});

/** Jour de Douala au format AAAA-MM-JJ, décalé de [offsetDays] jours. */
export function doualaDay(now: Date, offsetDays = 0): string {
  return dayParts.format(new Date(now.getTime() + offsetDays * 86_400_000));
}

/** Périodes de la liste des commandes : jours de création, heure de Douala. */
export const PERIODS = [
  { value: 'tout', label: 'Toutes dates' },
  { value: 'jour', label: 'Aujourd’hui' },
  { value: 'hier', label: 'Hier' },
  { value: '7j', label: '7 derniers jours' },
] as const;
export type Period = (typeof PERIODS)[number]['value'];

export function periodRange(period: string | undefined, now: Date): { from?: string; to?: string } {
  switch (period) {
    case 'jour':
      return { from: doualaDay(now), to: doualaDay(now) };
    case 'hier':
      return { from: doualaDay(now, -1), to: doualaDay(now, -1) };
    case '7j':
      return { from: doualaDay(now, -6), to: doualaDay(now) };
    default:
      return {};
  }
}
