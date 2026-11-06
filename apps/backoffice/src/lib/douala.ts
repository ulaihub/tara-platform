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
