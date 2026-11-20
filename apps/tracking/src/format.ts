/** Heure de Douala (UTC+1), où vivent les destinataires. */
const TIME_ZONE = 'Africa/Douala';

const clock = new Intl.DateTimeFormat('fr-FR', {
  timeZone: TIME_ZONE,
  hour: '2-digit',
  minute: '2-digit',
});

/** « 10:42 ». */
export function formatClock(iso: string | Date): string {
  return clock.format(typeof iso === 'string' ? new Date(iso) : iso);
}

/** « 12 500 F » avec des espaces insécables, comme dans les apps. */
export function formatAmount(amount: number): string {
  const digits = Math.round(amount)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return `${digits} F`;
}

/**
 * Jour d'une livraison programmée, relatif à aujourd'hui (heure de Douala) : `today`,
 * `tomorrow` ou la date « 05/11 ».
 */
export function dayOf(iso: string, now: Date): string {
  const day = (date: Date) =>
    new Intl.DateTimeFormat('fr-CA', { timeZone: TIME_ZONE }).format(date);
  const target = day(new Date(iso));
  if (target === day(now)) return 'today';
  if (target === day(new Date(now.getTime() + 86_400_000))) return 'tomorrow';
  return new Intl.DateTimeFormat('fr-FR', {
    timeZone: TIME_ZONE,
    day: '2-digit',
    month: '2-digit',
  }).format(new Date(iso));
}

/** « Jean M. » → « JM ». */
export function initials(name: string): string {
  return name
    .split(/\s+/)
    .map((part) => part[0] ?? '')
    .join('')
    .replace(/[^\p{L}]/gu, '')
    .slice(0, 2)
    .toUpperCase();
}

/** « 6 novembre à 18:00 » (heure de Douala), « 6 November at 18:00 » en anglais. */
export function formatDayTime(iso: string, locale: 'fr' | 'en'): string {
  const day = new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
    timeZone: TIME_ZONE,
    day: 'numeric',
    month: 'long',
  }).format(new Date(iso));
  return `${day} ${locale === 'fr' ? 'à' : 'at'} ${formatClock(iso)}`;
}

/** « 06/11 » (heure de Douala) : en-tête de la page du lien de localisation. */
export function formatShortDay(iso: string): string {
  return new Intl.DateTimeFormat('fr-FR', {
    timeZone: TIME_ZONE,
    day: '2-digit',
    month: '2-digit',
  }).format(new Date(iso));
}

/** « 19/11/2026 » (heure de Douala) : dates du reçu. */
export function formatDate(iso: string): string {
  return new Intl.DateTimeFormat('fr-FR', {
    timeZone: TIME_ZONE,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(new Date(iso));
}
