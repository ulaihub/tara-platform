import { z } from 'zod';
import { CameroonMobile, normalizeCameroonMobile } from '../common/phone.js';

/**
 * Variables d'environnement de l'API, validées au démarrage.
 * Une variable manquante ou invalide arrête le processus avec un message clair,
 * plutôt qu'une erreur obscure plus tard en production.
 */
const MAX_SMS_TEST_NUMBERS = 20;

const base64Key32 = z.string().refine((value) => Buffer.from(value, 'base64').length === 32, {
  message: 'doit être une clé de 32 octets encodée en base64 (openssl rand -base64 32)',
});

/** Numéro d'urgence court (police, pompiers, SAMU) : 2 à 4 chiffres. */
const EmergencyNumber = z.string().regex(/^\d{2,4}$/, 'numéro d’urgence de 2 à 4 chiffres');

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
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).max(90).default(90),
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

    /**
     * Fichiers (photos, notes vocales, pièces d'identité chiffrées) : disque local en
     * développement, stockage objet compatible S3 en production (tout hébergeur : le lieu
     * des données se choisit avec l'avis juridique sur les transferts hors du Cameroun).
     */
    STORAGE_DRIVER: z.enum(['local', 's3']).default('local'),
    STORAGE_LOCAL_DIR: z.string().min(1).default('./var/storage'),
    /** Adresse du service S3 de l'hébergeur ; vide pour Amazon S3 lui-même. */
    S3_ENDPOINT: z.url().optional(),
    S3_REGION: z.string().min(1).default('us-east-1'),
    S3_BUCKET: z.string().min(3).max(63).optional(),
    S3_ACCESS_KEY_ID: z.string().min(1).optional(),
    S3_SECRET_ACCESS_KEY: z.string().min(1).optional(),
    /** Adresses « endpoint/bucket/clé » (MinIO et la plupart des hébergeurs hors Amazon). */
    S3_FORCE_PATH_STYLE: z
      .enum(['true', 'false'])
      .default('true')
      .transform((value) => value === 'true'),
    /** Clé de chiffrement des pièces d'identité (AES-256-GCM). */
    STORAGE_ENCRYPTION_KEY: base64Key32,
    /**
     * Rotation de la clé : l'ancienne, encore acceptée pour lire, le temps que
     * `storage:rotate-key` rechiffre tout avec la nouvelle (docs/SECURITE.md).
     */
    STORAGE_ENCRYPTION_KEY_PREVIOUS: base64Key32.optional(),

    /**
     * SMS : Orange Cameroun (API officielle, tous opérateurs) en principal et Twilio en
     * secours, utilisé seulement si le principal échoue. « fake » écrit dans le journal.
     */
    SMS_PROVIDER: z.enum(['fake', 'orange', 'twilio']).default('fake'),
    SMS_FALLBACK_PROVIDER: z.enum(['none', 'orange', 'twilio']).default('none'),
    ORANGE_SMS_CLIENT_ID: z.string().min(8).optional(),
    ORANGE_SMS_CLIENT_SECRET: z.string().min(8).optional(),
    /** Numéro du compte Orange émetteur, au format +2376XXXXXXXX. */
    ORANGE_SMS_SENDER_PHONE: z
      .string()
      .regex(/^\+2376\d{8}$/)
      .optional(),
    /** Nom d'expéditeur validé par Orange (11 caractères au plus), ex. « TARA ». */
    ORANGE_SMS_SENDER_NAME: z.string().min(1).max(11).optional(),
    TWILIO_ACCOUNT_SID: z
      .string()
      .regex(/^AC[0-9a-f]{32}$/)
      .optional(),
    TWILIO_AUTH_TOKEN: z.string().min(16).optional(),
    /** Expéditeur Twilio : nom alphanumérique enregistré (ex. TARA) ou numéro E.164. */
    TWILIO_FROM: z.string().min(1).max(16).optional(),
    /**
     * Téléphones de test, séparés par des virgules (20 au plus) : leurs SMS ne partent pas chez
     * l'opérateur, ils restent 24 h sur le serveur, lisibles par root avec `tara sms`. Sert à
     * tester les apps sans crédit SMS ; jamais le numéro d'un vrai client.
     */
    SMS_TEST_NUMBERS: z.string().default(''),
    /** Au-delà de ce nombre de SMS dans la journée, l'équipe est alertée (80 % puis 100 %). */
    SMS_DAILY_ALERT_COUNT: z.coerce.number().int().min(1).default(3000),
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
    /** Secret de l'app Meta : vérifie la signature des accusés de remise (webhook). */
    WHATSAPP_APP_SECRET: z.string().min(16).optional(),
    /** Jeton choisi par Tara, demandé par Meta à l'enregistrement du webhook. */
    WHATSAPP_VERIFY_TOKEN: z.string().min(16).optional(),
    /**
     * Codes de connexion par WhatsApp (SMS en secours) : à activer une fois le modèle
     * d'authentification `tara_otp` approuvé chez Meta (docs/DEPLOIEMENT.md).
     */
    WHATSAPP_OTP: booleanFlag.default(false),
    /**
     * Empreintes des apps Android (11 caractères, séparées par des virgules) : ajoutées à la
     * fin du SMS de code, elles permettent au téléphone de remettre le code à l'app sans rien
     * taper. Seules celles-ci sont acceptées ; `tara apk` les règle.
     */
    SMS_APP_HASHES: z.string().default(''),
    /** Numéros de l'équipe prévenus par SMS en cas d'alerte de sécurité d'un livreur (SOS). */
    OPS_ALERT_PHONES: z.string().default(''),
    /** Ligne de secours Tara (24 h/24), affichée sur l'écran d'alerte de l'app livreur. */
    SAFETY_HOTLINE_PHONE: CameroonMobile.default('+237640114064'),
    /** Numéros d'urgence affichés sur l'écran d'alerte : police, pompiers, SAMU (Cameroun). */
    EMERGENCY_POLICE_NUMBER: EmergencyNumber.default('117'),
    EMERGENCY_FIRE_NUMBER: EmergencyNumber.default('118'),
    EMERGENCY_MEDICAL_NUMBER: EmergencyNumber.default('119'),
    /**
     * Échec de livraison (E6) : appels au destinataire exigés pour « absent », « injoignable »
     * et « adresse introuvable », écart minimal entre le premier et le dernier, puis délai
     * laissé à l'expéditeur pour choisir avant le retour automatique.
     */
    FAILURE_MIN_CALLS: z.coerce.number().int().min(1).max(5).default(2),
    FAILURE_CALL_SPACING_MINUTES: z.coerce.number().min(0).max(60).default(5),
    FAILURE_DECISION_TIMEOUT_MINUTES: z.coerce.number().min(0.05).max(240).default(15),
    /**
     * Dette maximale d'un marchand envers Tara (frais d'échec non couverts par son solde), en
     * FCFA : au-delà, les frais se paient sur le moment et les nouvelles commandes attendent
     * le règlement. Un particulier ne peut rien devoir.
     */
    MERCHANT_DEBT_LIMIT: z.coerce.number().int().min(0).max(100_000).default(3_000),
    /**
     * Liens « placez votre point » envoyés par SMS au plus par compte et par 24 h (envoi en
     * masse, relances) : Tara ne doit pas servir à écrire en nombre à n'importe qui.
     */
    PENDING_LINKS_DAILY_LIMIT: z.coerce.number().int().min(1).max(5_000).default(300),
    /**
     * Espèces encore dues d'avant le solde prépayé (G5) : délai de dépôt, puis retard au-delà
     * duquel le compte est suspendu (gains retenus).
     */
    CASH_DEPOSIT_DEADLINE_HOURS: z.coerce.number().min(1).max(240).default(24),
    CASH_OVERDUE_SUSPEND_HOURS: z.coerce.number().min(1).max(720).default(72),
    /** Ligne du support Tara, affichée dans l'app livreur ; sans valeur, le bouton est masqué. */
    SUPPORT_PHONE: CameroonMobile.optional(),

    /** Attribution des courses (D1, D2). Valeurs réduites par le simulateur. */
    DISPATCH_OFFER_TIMEOUT_SECONDS: z.coerce.number().min(0.2).max(300).default(30),
    DISPATCH_SINGLE_OFFER_ROUNDS: z.coerce.number().int().min(1).max(10).default(3),
    DISPATCH_BROADCAST_SIZE: z.coerce.number().int().min(2).max(20).default(5),
    DISPATCH_RADII_METERS: z.string().default('3000,5000,8000,12000'),
    DISPATCH_RETRY_SECONDS: z.coerce.number().min(0.2).max(300).default(20),
    DISPATCH_ALERT_AFTER_SECONDS: z.coerce.number().min(1).max(3600).default(300),
    /** Confiance progressive selon la valeur déclarée du colis (voir rider-scoring.ts). */
    DISPATCH_NEW_RIDER_DELIVERIES: z.coerce.number().int().min(0).max(1000).default(20),
    DISPATCH_NEW_RIDER_MAX_VALUE: z.coerce.number().int().min(0).default(25_000),
    DISPATCH_HIGH_VALUE_FROM: z.coerce.number().int().min(0).default(100_000),
    DISPATCH_HIGH_VALUE_MIN_DELIVERIES: z.coerce.number().int().min(0).max(10_000).default(50),
    DISPATCH_HIGH_VALUE_MIN_RATING: z.coerce.number().min(1).max(5).default(4.5),
    /**
     * Retards signalés sur la carte du back-office (H1) : livreur pas encore au vendeur
     * [LATE_PICKUP_MINUTES] après l'attribution ; colis pas livré après le trajet estimé
     * (300 m par minute) plus [LATE_DELIVERY_MARGIN_MINUTES].
     */
    LATE_PICKUP_MINUTES: z.coerce.number().int().min(1).max(240).default(25),
    LATE_DELIVERY_MARGIN_MINUTES: z.coerce.number().int().min(0).max(240).default(15),
    /** Position considérée comme périmée au-delà de ce délai (livreur hors ligne de fait). */
    RIDER_POSITION_TTL_SECONDS: z.coerce.number().int().min(10).max(600).default(90),
    /** Au-delà de ce montant à encaisser, une livraison sans code exige un administrateur. */
    SUPPORT_VALIDATION_LIMIT: z.coerce.number().int().min(0).default(50000),

    /**
     * Agrégateur Mobile Money (G1, G3). « fake » simule les paiements (interdit en
     * production) ; « campay » ou « sebpay » : MTN MoMo et Orange Money au Cameroun.
     */
    PAYMENT_PROVIDER: z.enum(['fake', 'campay', 'sebpay']).default('fake'),
    /** Bac à sable par défaut ; réel : https://newapi.sebpay.bj/api/v1 (clés pk_live_). */
    SEBPAY_BASE_URL: z.url({ protocol: /^https$/ }).default('https://api.sandbox.sebpay.bj/api/v1'),
    SEBPAY_PUBLIC_KEY: z
      .string()
      .regex(/^pk_(test|live)_/, 'clé publique pk_test_… ou pk_live_…')
      .optional(),
    SEBPAY_SECRET_KEY: z
      .string()
      .regex(/^sk_(test|live)_/, 'clé secrète sk_test_… ou sk_live_…')
      .optional(),
    /**
     * Adresse publique de l'API (https), d'où Sebpay est rappelé :
     * {PUBLIC_API_URL}/v1/webhooks/payments/sebpay.
     */
    PUBLIC_API_URL: z.url({ protocol: /^https$/ }).optional(),
    CAMPAY_BASE_URL: z.url({ protocol: /^https$/ }).default('https://demo.campay.net/api'),
    CAMPAY_USERNAME: z.string().min(1).optional(),
    CAMPAY_PASSWORD: z.string().min(1).optional(),
    CAMPAY_WEBHOOK_KEY: z.string().min(16).optional(),
    /**
     * Analyse de la photo du colis (taille, nature, objets interdits proposés) : « claude »
     * (ANTHROPIC_API_KEY), « fake » (développement, interdit en production) ou « none »
     * (l'expéditeur choisit seul).
     */
    PARCEL_VISION_PROVIDER: z.enum(['none', 'fake', 'claude']).default('fake'),
    ANTHROPIC_API_KEY: z.string().min(1).optional(),
    PARCEL_VISION_MODEL: z.string().min(1).default('claude-opus-5-5'),
    /** Analyses de photo par compte et par heure (coût du modèle). */
    PARCEL_ANALYSIS_PER_HOUR: z.coerce.number().int().min(1).max(500).default(20),
    /** Une demande de paiement sans réponse est abandonnée après ce délai. */
    PAYMENT_REQUEST_TIMEOUT_MINUTES: z.coerce.number().int().min(1).max(60).default(10),
    /**
     * Annulation par l'expéditeur quand le livreur est déjà en route vers l'enlèvement : frais
     * payés par l'expéditeur, dont la part du livreur pour son déplacement ; le reste à Tara.
     */
    CANCELLATION_FEE: z.coerce.number().int().min(0).max(5000).default(300),
    CANCELLATION_FEE_RIDER_PART: z.coerce.number().int().min(0).max(5000).default(200),
    /**
     * Attente au point d'enlèvement, comptée depuis « Je suis arrivé » : gratuite pendant
     * WAITING_FREE_MINUTES, puis WAITING_FEE_PER_STEP par tranche de WAITING_STEP_MINUTES
     * commencée, payés par l'expéditeur ; WAITING_RIDER_PERCENT pour le livreur.
     */
    WAITING_FREE_MINUTES: z.coerce.number().int().min(0).max(120).default(10),
    WAITING_STEP_MINUTES: z.coerce.number().int().min(1).max(60).default(5),
    WAITING_FEE_PER_STEP: z.coerce.number().int().min(0).max(5000).default(100),
    WAITING_RIDER_PERCENT: z.coerce.number().int().min(0).max(100).default(70),
    /** Plafond des frais d'attente : jamais plus que le prix d'une petite course (1 h d'attente). */
    WAITING_FEE_MAX: z.coerce.number().int().min(0).max(20_000).default(1000),
    /** Reversement minimal, et seuil au-delà duquel la finance valide avant l'envoi. */
    PAYOUT_MIN_AMOUNT: z.coerce.number().int().min(1).default(500),
    /**
     * Frais Mobile Money du prestataire à l'encaissement, en points de base (600 = 6 % pour un
     * compte Sebpay particulier) : ajoutés au montant payé par le client.
     */
    MOBILE_MONEY_FEE_BPS: z.coerce.number().int().min(0).max(2000).default(0),
    /** Frais du prestataire sur un reversement (250 = 2,5 %) : retenus sur le montant envoyé. */
    PAYOUT_FEE_BPS: z.coerce.number().int().min(0).max(2000).default(0),
    /**
     * Part des frais de retrait payée par le bénéficiaire sous le seuil de gratuité, en % ;
     * Tara paie le reste (50 : moitié-moitié, 100 : tout pour le bénéficiaire).
     */
    PAYOUT_FEE_SHARE_PERCENT: z.coerce.number().int().min(0).max(100).default(50),
    /** Seuil général de retrait gratuit (boutiques et livreurs sans seuil propre). */
    FREE_PAYOUT_FROM: z.coerce.number().int().min(0).default(50_000),
    PAYOUT_APPROVAL_THRESHOLD: z.coerce.number().int().min(1).default(200_000),
    /** Heure du reversement quotidien des marchands, heure du Cameroun (G3). */
    PAYOUT_DAILY_HOUR: z.coerce.number().int().min(0).max(23).default(18),
    /**
     * Après un changement du numéro de reversement d'un marchand, les reversements attendent
     * ce délai : un compte pris par détournement de carte SIM ne peut pas vider le portefeuille.
     */
    PAYOUT_HOLD_HOURS: z.coerce.number().int().min(0).max(240).default(48),

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
        'WHATSAPP_APP_SECRET',
        'WHATSAPP_VERIFY_TOKEN',
      ] as const) {
        if (!env[key])
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: 'requis avec WHATSAPP_PROVIDER=meta',
          });
      }
    }
    const required: Record<'orange' | 'twilio', (keyof typeof env)[]> = {
      orange: ['ORANGE_SMS_CLIENT_ID', 'ORANGE_SMS_CLIENT_SECRET', 'ORANGE_SMS_SENDER_PHONE'],
      twilio: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_FROM'],
    };
    for (const provider of [env.SMS_PROVIDER, env.SMS_FALLBACK_PROVIDER]) {
      if (provider !== 'orange' && provider !== 'twilio') continue;
      for (const key of required[provider]) {
        if (!env[key]) {
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: `requis avec le fournisseur SMS ${provider}`,
          });
        }
      }
    }
    if (env.SMS_FALLBACK_PROVIDER !== 'none' && env.SMS_FALLBACK_PROVIDER === env.SMS_PROVIDER) {
      ctx.addIssue({
        code: 'custom',
        path: ['SMS_FALLBACK_PROVIDER'],
        message: 'le secours doit être un autre fournisseur que le principal',
      });
    }
    if (env.PAYMENT_PROVIDER === 'campay') {
      for (const key of ['CAMPAY_USERNAME', 'CAMPAY_PASSWORD', 'CAMPAY_WEBHOOK_KEY'] as const) {
        if (!env[key])
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: 'requis avec PAYMENT_PROVIDER=campay',
          });
      }
    }
    if (env.PARCEL_VISION_PROVIDER === 'claude' && !env.ANTHROPIC_API_KEY) {
      ctx.addIssue({
        code: 'custom',
        path: ['ANTHROPIC_API_KEY'],
        message: 'requis avec PARCEL_VISION_PROVIDER=claude',
      });
    }
    if (env.PAYMENT_PROVIDER === 'sebpay') {
      for (const key of ['SEBPAY_PUBLIC_KEY', 'SEBPAY_SECRET_KEY', 'PUBLIC_API_URL'] as const) {
        if (!env[key])
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: 'requis avec PAYMENT_PROVIDER=sebpay',
          });
      }
      // Clés et serveur du même environnement : sandbox avec _test_, réel avec _live_.
      const sandbox = env.SEBPAY_BASE_URL.includes('sandbox');
      for (const key of ['SEBPAY_PUBLIC_KEY', 'SEBPAY_SECRET_KEY'] as const) {
        const value = env[key];
        if (value && value.includes('_test_') !== sandbox)
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: sandbox
              ? 'clé réelle (_live_) envoyée au bac à sable'
              : 'clé de test (_test_) envoyée au serveur réel',
          });
      }
    }
    if (env.STORAGE_DRIVER === 's3') {
      for (const name of ['S3_BUCKET', 'S3_ACCESS_KEY_ID', 'S3_SECRET_ACCESS_KEY'] as const) {
        if (!env[name]) {
          ctx.addIssue({
            code: 'custom',
            path: [name],
            message: 'obligatoire avec STORAGE_DRIVER=s3',
          });
        }
      }
    }
    if (env.STORAGE_ENCRYPTION_KEY_PREVIOUS === env.STORAGE_ENCRYPTION_KEY) {
      ctx.addIssue({
        code: 'custom',
        path: ['STORAGE_ENCRYPTION_KEY_PREVIOUS'],
        message: 'doit différer de STORAGE_ENCRYPTION_KEY',
      });
    }
    const radii = env.DISPATCH_RADII_METERS.split(',').map(Number);
    if (radii.some((r) => !Number.isInteger(r) || r <= 0)) {
      ctx.addIssue({
        code: 'custom',
        path: ['DISPATCH_RADII_METERS'],
        message: 'liste de rayons en mètres attendue',
      });
    }
    const appHashes = env.SMS_APP_HASHES.split(',')
      .map((hash) => hash.trim())
      .filter(Boolean);
    if (appHashes.some((hash) => !SMS_APP_HASH.test(hash))) {
      ctx.addIssue({
        code: 'custom',
        path: ['SMS_APP_HASHES'],
        message:
          'empreintes de 11 caractères (lettres, chiffres, + et /) séparées par des virgules',
      });
    }
    if (env.WHATSAPP_OTP && env.WHATSAPP_PROVIDER === 'none') {
      ctx.addIssue({
        code: 'custom',
        path: ['WHATSAPP_OTP'],
        message: 'WhatsApp doit être configuré (WHATSAPP_PROVIDER)',
      });
    }
    const testNumbers = env.SMS_TEST_NUMBERS.split(',')
      .map((phone) => phone.trim())
      .filter(Boolean);
    if (testNumbers.some((phone) => !normalizeCameroonMobile(phone))) {
      ctx.addIssue({
        code: 'custom',
        path: ['SMS_TEST_NUMBERS'],
        message: 'numéros de mobile camerounais séparés par des virgules attendus',
      });
    } else if (testNumbers.length > MAX_SMS_TEST_NUMBERS) {
      ctx.addIssue({
        code: 'custom',
        path: ['SMS_TEST_NUMBERS'],
        message: `${MAX_SMS_TEST_NUMBERS} numéros de test au plus`,
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
    if (env.PAYMENT_PROVIDER === 'fake') {
      ctx.addIssue({
        code: 'custom',
        path: ['PAYMENT_PROVIDER'],
        message: 'le prestataire de paiement factice est interdit en production',
      });
    }
    if (env.PARCEL_VISION_PROVIDER === 'fake') {
      ctx.addIssue({
        code: 'custom',
        path: ['PARCEL_VISION_PROVIDER'],
        message: 'l’analyse factice des photos de colis est interdite en production',
      });
    }
    if (env.PAYMENT_PROVIDER === 'sebpay' && env.SEBPAY_BASE_URL.includes('sandbox')) {
      ctx.addIssue({
        code: 'custom',
        path: ['SEBPAY_BASE_URL'],
        message: 'le bac à sable Sebpay est interdit en production',
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

/** Clés de chiffrement du stockage : l'actuelle d'abord, puis l'ancienne pendant une rotation. */
export function storageKeys(env: Env): Buffer[] {
  const keys = [Buffer.from(env.STORAGE_ENCRYPTION_KEY, 'base64')];
  if (env.STORAGE_ENCRYPTION_KEY_PREVIOUS) {
    keys.push(Buffer.from(env.STORAGE_ENCRYPTION_KEY_PREVIOUS, 'base64'));
  }
  return keys;
}

/** Téléphones de test (SMS gardés sur le serveur), normalisés au format +2376XXXXXXXX. */
export function smsTestNumbers(env: Env): Set<string> {
  return new Set(
    env.SMS_TEST_NUMBERS.split(',')
      .map((phone) => normalizeCameroonMobile(phone.trim()))
      .filter((phone): phone is string => phone !== null),
  );
}

/** Empreinte d'une app Android dans un SMS (SMS Retriever) : 11 caractères base64. */
export const SMS_APP_HASH = /^[A-Za-z0-9+/]{11}$/;

/** Empreintes des apps Tara autorisées à la fin des SMS de code. */
export function smsAppHashes(env: Pick<Env, 'SMS_APP_HASHES'>): Set<string> {
  return new Set(
    env.SMS_APP_HASHES.split(',')
      .map((hash) => hash.trim())
      .filter((hash) => SMS_APP_HASH.test(hash)),
  );
}
