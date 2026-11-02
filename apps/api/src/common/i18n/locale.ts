export type AppLocale = 'fr' | 'en';

/**
 * Langue de la réponse : celle du compte connecté si elle est connue,
 * sinon la première langue reconnue de l'en-tête Accept-Language, sinon le français.
 */
export function resolveLocale(
  acceptLanguage: string | undefined,
  userLocale?: 'FR' | 'EN',
): AppLocale {
  if (userLocale) return userLocale === 'EN' ? 'en' : 'fr';
  if (!acceptLanguage) return 'fr';
  for (const part of acceptLanguage.split(',')) {
    const tag = part.trim().slice(0, 2).toLowerCase();
    if (tag === 'fr' || tag === 'en') return tag;
  }
  return 'fr';
}

export function interpolate(template: string, params: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (match, key: string) =>
    key in params ? String(params[key]) : match,
  );
}
