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
