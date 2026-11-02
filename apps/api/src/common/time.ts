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
