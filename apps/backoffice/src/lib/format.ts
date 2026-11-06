/** Mise en forme française (heure de Douala, montants en FCFA, durées). */
const TIME_ZONE = 'Africa/Douala';

const clock = new Intl.DateTimeFormat('fr-FR', {
  hour: '2-digit',
  minute: '2-digit',
  timeZone: TIME_ZONE,
});

const amount = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 });

/** « 14:05 ». */
export function time(iso: string | Date): string {
  return clock.format(typeof iso === 'string' ? new Date(iso) : iso);
}

/** « 12 500 F » (espace insécable fine comme séparateur de milliers). */
export function money(value: number): string {
  return `${amount.format(value)} F`;
}

/** « à l'instant », « il y a 45 s », « il y a 12 min », « il y a 2 h 05 ». */
export function ago(iso: string, now: number): string {
  const seconds = Math.max(0, Math.round((now - new Date(iso).getTime()) / 1000));
  if (seconds < 5) return 'à l’instant';
  if (seconds < 60) return `il y a ${seconds} s`;
  return `il y a ${duration(Math.floor(seconds / 60))}`;
}

/** Durée en minutes : « 12 min », « 1 h », « 2 h 05 ». */
export function duration(minutes: number): string {
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0 ? `${hours} h` : `${hours} h ${String(rest).padStart(2, '0')}`;
}

/** Prénom, ou numéro masqué faute de nom. */
export function firstName(name: string | null, phone: string): string {
  const first = name?.trim().split(/\s+/)[0];
  return first || `…${phone.slice(-4)}`;
}

/** « 850 m », « 2,4 km ». */
export function distance(meters: number): string {
  if (meters < 1000) return `${Math.round(meters / 10) * 10} m`;
  return `${(meters / 1000).toFixed(1).replace('.', ',')} km`;
}
