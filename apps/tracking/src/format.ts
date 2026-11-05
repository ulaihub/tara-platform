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

/** « 1,2 km » ou « 350 m ». */
export function formatDistance(meters: number, locale: 'fr' | 'en'): string {
  if (meters < 1000) return `${Math.max(50, Math.round(meters / 50) * 50)} m`;
  const km = (meters / 1000).toFixed(1);
  return `${locale === 'fr' ? km.replace('.', ',') : km} km`;
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
