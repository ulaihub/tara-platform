/** Fuseau du Cameroun : heure d'Afrique de l'Ouest (UTC+1), sans heure d'été. */
export const CAMEROON_TIME_ZONE = 'Africa/Douala';

const hourFormatter = new Intl.DateTimeFormat('en-GB', {
  timeZone: CAMEROON_TIME_ZONE,
  hour: '2-digit',
  hourCycle: 'h23',
});

const dateFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: CAMEROON_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

/** Heure locale (0 à 23) au Cameroun. */
export function cameroonHour(at: Date): number {
  return Number(hourFormatter.format(at));
}

/** Date locale au Cameroun, au format AAAA-MM-JJ. */
export function cameroonDate(at: Date): string {
  return dateFormatter.format(at);
}

export function addMinutes(at: Date, minutes: number): Date {
  return new Date(at.getTime() + minutes * 60_000);
}

export function addDays(at: Date, days: number): Date {
  return new Date(at.getTime() + days * 86_400_000);
}

/** Début (UTC) du jour, de la semaine (lundi) ou du mois en cours au Cameroun. */
export function periodStart(period: 'day' | 'week' | 'month', now: Date): Date {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: CAMEROON_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
  }).formatToParts(now);
  const get = (type: string): string => parts.find((part) => part.type === type)?.value ?? '';
  const year = Number(get('year'));
  const month = Number(get('month'));
  const day = Number(get('day'));
  const weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(get('weekday'));
  // Le Cameroun est à UTC+1 toute l'année (pas d'heure d'été).
  const localMidnight = (y: number, m: number, d: number): Date =>
    new Date(Date.UTC(y, m - 1, d) - 3_600_000);
  switch (period) {
    case 'day':
      return localMidnight(year, month, day);
    case 'week':
      return localMidnight(year, month, day - weekday);
    case 'month':
      return localMidnight(year, month, 1);
  }
}

/** Jours fériés à date fixe au Cameroun (MM-JJ). */
const FIXED_HOLIDAYS = new Set(['01-01', '02-11', '05-01', '05-20', '08-15', '12-25']);
/** Marge pour les fêtes à date mobile (Vendredi saint, Ascension, Aïd) : jamais moins que la loi. */
const MOVABLE_HOLIDAYS_GRACE_DAYS = 2;

/**
 * Fin du délai pour signaler un colis abîmé : 7 jours après la livraison, dimanches et jours
 * fériés non compris (Acte uniforme OHADA relatif aux contrats de transport de marchandises
 * par route, art. 14), plus une marge pour les fêtes à date mobile ; minuit, heure du Cameroun.
 */
export function damageClaimDeadline(deliveredAt: Date): Date {
  // Minuit au Cameroun (UTC+1, sans heure d'été) du jour de la livraison.
  let cursor = new Date(`${cameroonDate(deliveredAt)}T00:00:00+01:00`);
  let counted = 0;
  while (counted < 7) {
    cursor = addDays(cursor, 1);
    // Midi local : jour de la semaine et date sans ambiguïté de fuseau.
    const noon = new Date(cursor.getTime() + 12 * 3_600_000);
    const sunday = noon.getUTCDay() === 0;
    const holiday = FIXED_HOLIDAYS.has(cameroonDate(noon).slice(5));
    if (!sunday && !holiday) counted += 1;
  }
  return addDays(cursor, 1 + MOVABLE_HOLIDAYS_GRACE_DAYS);
}
