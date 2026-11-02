import { z } from 'zod';

/**
 * Variables d'environnement de l'API, validées au démarrage.
 * Une variable manquante ou invalide arrête le processus avec un message clair,
 * plutôt qu'une erreur obscure plus tard en production.
 */
const base64Key32 = z.string().refine((value) => Buffer.from(value, 'base64').length === 32, {
  message: 'doit être une clé de 32 octets encodée en base64 (openssl rand -base64 32)',
});

const booleanFlag = z
  .enum(['true', 'false', '1', '0'])
  .transform((value) => value === 'true' || value === '1');

const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
    DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/ }),
    /** Redis 7 : positions des livreurs, files de tâches, limitation de débit, temps réel. */
    REDIS_URL: z.url({ protocol: /^rediss?$/ }),
    /** Préfixe des files de tâches (une valeur par environnement partageant un même Redis). */
    QUEUE_PREFIX: z.string().min(1).default('tara'),
    OSRM_URL: z.url().optional(),

    /** Adresse publique des pages web (suivi, lien de localisation). */
    PUBLIC_WEB_URL: z.url().default('http://localhost:3001'),
    DEFAULT_CITY: z.string().min(1).default('Douala'),

    JWT_SECRET: z.string().min(32, 'doit contenir au moins 32 caractères'),
    /** Ancien secret, encore accepté en vérification pendant une rotation de clé. */
    JWT_SECRET_PREVIOUS: z.string().min(32, 'doit contenir au moins 32 caractères').optional(),
    JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().min(60).max(3600).default(900),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).max(90).default(30),
    /** Secret mélangé aux codes courts (SMS, enlèvement, livraison) avant hachage. */
    CODE_HASH_SECRET: z.string().min(32, 'doit contenir au moins 32 caractères'),
    OTP_TTL_SECONDS: z.coerce.number().int().min(60).max(900).default(300),
    /**
     * Plafonds d'envoi de codes SMS contre le « pompage » (envois massifs pour faire payer
     * les SMS). Les limites par IP restent larges : au Cameroun, beaucoup d'abonnés
     * mobiles partagent la même adresse IP publique (CGNAT des opérateurs).
     */
    OTP_MAX_PER_IP_PER_HOUR: z.coerce.number().int().min(1).default(300),
    OTP_DAILY_GLOBAL_LIMIT: z.coerce.number().int().min(1).default(5000),
    /** Durée de validité de la double authentification de l'équipe, en heures. */
    MFA_SESSION_HOURS: z.coerce.number().int().min(1).max(24).default(12),

    /**
     * Relais de confiance devant l'API, pour lire la vraie adresse IP du client
     * (réglage « trust proxy » d'Express) : « loopback », un nombre de relais ou des plages
     * CIDR séparées par des virgules. Jamais « true » en production (adresse falsifiable).
     */
    TRUST_PROXY: z.string().min(1).default('loopback'),
    /** Origines web autorisées (back-office, page de suivi), séparées par des virgules. */
    CORS_ORIGINS: z.string().default(''),

    STORAGE_DRIVER: z.enum(['local']).default('local'),
    STORAGE_LOCAL_DIR: z.string().min(1).default('./var/storage'),
    /** Clé de chiffrement des pièces d'identité (AES-256-GCM). */
    STORAGE_ENCRYPTION_KEY: base64Key32,

    SMS_PROVIDER: z.enum(['fake']).default('fake'),
    /** Notifications push (Firebase Cloud Messaging) : compte de service JSON encodé en base64. */
    PUSH_PROVIDER: z.enum(['fake', 'fcm']).default('fake'),
    FCM_SERVICE_ACCOUNT_BASE64: z.string().optional(),
    /** WhatsApp Cloud API (Meta) : désactivé par défaut, les messages partent alors par SMS. */
    WHATSAPP_PROVIDER: z.enum(['none', 'fake', 'meta']).default('none'),
    WHATSAPP_PHONE_NUMBER_ID: z.string().optional(),
    WHATSAPP_ACCESS_TOKEN: z.string().optional(),
    /** Version de l'API Graph, ex. « v23.0 » : prendre celle indiquée dans le tableau de bord Meta. */
    WHATSAPP_API_VERSION: z
      .string()
      .regex(/^v\d+\.\d+$/)
      .optional(),
    /** Numéros de l'équipe prévenus par SMS en cas d'alerte de sécurité d'un livreur (SOS). */
    OPS_ALERT_PHONES: z.string().default(''),

    /** Attribution des courses (D1, D2). Valeurs réduites par le simulateur. */
    DISPATCH_OFFER_TIMEOUT_SECONDS: z.coerce.number().min(0.2).max(300).default(30),
    DISPATCH_SINGLE_OFFER_ROUNDS: z.coerce.number().int().min(1).max(10).default(3),
    DISPATCH_BROADCAST_SIZE: z.coerce.number().int().min(2).max(20).default(5),
    DISPATCH_RADII_METERS: z.string().default('3000,5000,8000,12000'),
    DISPATCH_RETRY_SECONDS: z.coerce.number().min(0.2).max(300).default(20),
    DISPATCH_ALERT_AFTER_SECONDS: z.coerce.number().min(1).max(3600).default(300),
    /** Position considérée comme périmée au-delà de ce délai (livreur hors ligne de fait). */
    RIDER_POSITION_TTL_SECONDS: z.coerce.number().int().min(10).max(600).default(90),
    /** Au-delà de ce montant à encaisser, une livraison sans code exige un administrateur. */
    SUPPORT_VALIDATION_LIMIT: z.coerce.number().int().min(0).default(50000),

    /** Tâches planifiées (expiration des pièces KYC…). Désactivées dans les tests. */
    JOBS_ENABLED: booleanFlag.default(true),
  })
  .superRefine((env, ctx) => {
    if (env.PUSH_PROVIDER === 'fcm' && !env.FCM_SERVICE_ACCOUNT_BASE64) {
      ctx.addIssue({
        code: 'custom',
        path: ['FCM_SERVICE_ACCOUNT_BASE64'],
        message: 'requis avec PUSH_PROVIDER=fcm',
      });
    }
    if (env.WHATSAPP_PROVIDER === 'meta') {
      for (const key of [
        'WHATSAPP_PHONE_NUMBER_ID',
        'WHATSAPP_ACCESS_TOKEN',
        'WHATSAPP_API_VERSION',
      ] as const) {
        if (!env[key])
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: 'requis avec WHATSAPP_PROVIDER=meta',
          });
      }
    }
    const radii = env.DISPATCH_RADII_METERS.split(',').map(Number);
    if (radii.some((r) => !Number.isInteger(r) || r <= 0)) {
      ctx.addIssue({
        code: 'custom',
        path: ['DISPATCH_RADII_METERS'],
        message: 'liste de rayons en mètres attendue',
      });
    }
    if (env.NODE_ENV !== 'production') return;
    if (env.SMS_PROVIDER === 'fake') {
      ctx.addIssue({
        code: 'custom',
        path: ['SMS_PROVIDER'],
        message: 'le fournisseur SMS factice est interdit en production',
      });
    }
    if (env.TRUST_PROXY.trim() === 'true') {
      ctx.addIssue({
        code: 'custom',
        path: ['TRUST_PROXY'],
        message: 'interdit en production : préciser le nombre de relais ou leurs adresses',
      });
    }
    if (env.PUSH_PROVIDER === 'fake') {
      ctx.addIssue({
        code: 'custom',
        path: ['PUSH_PROVIDER'],
        message: 'le fournisseur de notifications push factice est interdit en production',
      });
    }
    if (env.STORAGE_DRIVER === 'local') {
      ctx.addIssue({
        code: 'custom',
        path: ['STORAGE_DRIVER'],
        message: 'le stockage local est interdit en production (utiliser un stockage objet)',
      });
    }
  });

export type Env = z.infer<typeof envSchema>;

export class InvalidEnvironmentError extends Error {
  constructor(issues: string[]) {
    super(`Configuration invalide :\n${issues.map((issue) => `  - ${issue}`).join('\n')}`);
    this.name = 'InvalidEnvironmentError';
  }
}

export function parseEnv(source: Record<string, string | undefined>): Env {
  const result = envSchema.safeParse(source);
  if (!result.success) {
    throw new InvalidEnvironmentError(
      result.error.issues.map((issue) => `${issue.path.join('.')} : ${issue.message}`),
    );
  }
  return result.data;
}
