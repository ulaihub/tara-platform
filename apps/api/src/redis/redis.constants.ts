/** Jeton d'injection de la connexion Redis applicative. */
export const REDIS = Symbol('REDIS');

/** Toutes les clés applicatives sont préfixées : plusieurs environnements peuvent partager un Redis. */
export const REDIS_KEY_PREFIX = 'tara:';
