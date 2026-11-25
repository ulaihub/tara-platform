import { z } from 'zod';
import { CameroonMobile } from '../common/phone.js';
import { PageQuery } from '../common/pagination.js';
import type { KycDocumentType } from '../generated/prisma/enums.js';

export const KycDocumentTypeEnum = z
  .enum([
    'NATIONAL_ID_FRONT',
    'NATIONAL_ID_BACK',
    'DRIVING_LICENSE',
    'VEHICLE_REGISTRATION',
    'VEHICLE_RENTAL_CONTRACT',
    'INSURANCE',
    'SELFIE',
    'CRIMINAL_RECORD',
    'GUARANTOR_ID',
  ])
  .meta({ id: 'KycDocumentType' });

export const RiderStatusEnum = z
  .enum(['PENDING', 'ACTIVE', 'SUSPENDED', 'REJECTED'])
  .meta({ id: 'RiderStatus' });
export const VehicleTypeEnum = z.enum(['MOTORBIKE', 'TRICYCLE', 'CAR']).meta({ id: 'VehicleType' });

/**
 * Pièces exigées (A3). Chaque groupe doit être couvert par une pièce validée et non expirée ;
 * pour le véhicule, la carte grise OU le contrat de location suffit. La CNI du garant reste
 * acceptée (type GUARANTOR_ID) sans être exigée.
 */
export const REQUIRED_DOCUMENTS: KycDocumentType[][] = [
  ['NATIONAL_ID_FRONT'],
  ['NATIONAL_ID_BACK'],
  ['DRIVING_LICENSE'],
  ['VEHICLE_REGISTRATION', 'VEHICLE_RENTAL_CONTRACT'],
  ['INSURANCE'],
  ['SELFIE'],
  ['CRIMINAL_RECORD'],
  // Pas de CNI du garant : le garant est facultatif depuis le solde prépayé (décision 36).
];

export const DOCUMENT_LABELS: Record<KycDocumentType, { fr: string; en: string }> = {
  NATIONAL_ID_FRONT: { fr: 'CNI (recto)', en: 'National ID (front)' },
  NATIONAL_ID_BACK: { fr: 'CNI (verso)', en: 'National ID (back)' },
  DRIVING_LICENSE: { fr: 'Permis de conduire', en: 'Driving licence' },
  VEHICLE_REGISTRATION: { fr: 'Carte grise', en: 'Vehicle registration' },
  VEHICLE_RENTAL_CONTRACT: { fr: 'Contrat de location', en: 'Rental contract' },
  INSURANCE: { fr: 'Assurance', en: 'Insurance' },
  SELFIE: { fr: 'Photo du visage', en: 'Selfie' },
  CRIMINAL_RECORD: { fr: 'Casier judiciaire', en: 'Criminal record' },
  GUARANTOR_ID: { fr: 'CNI du garant', en: 'Guarantor ID' },
};

/** Pièces dont la date d'expiration est demandée à l'envoi (rappel avant échéance, A5). */
export const EXPIRING_DOCUMENTS: KycDocumentType[] = [
  'NATIONAL_ID_FRONT',
  'DRIVING_LICENSE',
  'INSURANCE',
  'VEHICLE_RENTAL_CONTRACT',
];

/** Une pièce exigée : l'un des types listés suffit (carte grise OU contrat de location). */
export const DocumentRequirementDto = z
  .object({
    types: z.array(
      z.object({
        type: KycDocumentTypeEnum,
        label: z.object({ fr: z.string(), en: z.string() }),
        asksExpiry: z.boolean(),
      }),
    ),
  })
  .meta({ id: 'DocumentRequirement' });

/** Proche prévenu par SMS si le livreur déclenche une alerte de sécurité (facultatif). */
export const EmergencyContactBody = z.object({
  name: z.string().trim().min(2).max(80),
  phone: CameroonMobile,
});

export const ApplyRiderBody = z.object({
  vehicleType: VehicleTypeEnum.default('MOTORBIKE'),
  plateNumber: z.string().trim().min(3).max(20).optional(),
  /** Garant facultatif : le solde prépayé (décision 36) couvre l'argent encaissé. */
  guarantorName: z.string().trim().min(2).max(80).optional(),
  guarantorPhone: CameroonMobile.optional(),
  emergencyContact: EmergencyContactBody.optional(),
});

export const UploadDocumentBody = z.object({
  type: KycDocumentTypeEnum,
  /** Date d'expiration inscrite sur le document, si elle existe (A5). */
  expiresOn: z.iso.date().optional(),
});

export const KycDocumentDto = z
  .object({
    id: z.uuid(),
    type: KycDocumentTypeEnum,
    status: z.enum(['PENDING', 'APPROVED', 'REJECTED', 'EXPIRED']),
    expiresOn: z.iso.date().nullable(),
    rejectionReason: z.string().nullable(),
    createdAt: z.iso.datetime(),
    reviewedAt: z.iso.datetime().nullable(),
  })
  .meta({ id: 'KycDocument' });

export const RiderProfileDto = z
  .object({
    id: z.uuid(),
    status: RiderStatusEnum,
    vehicleType: VehicleTypeEnum,
    plateNumber: z.string().nullable(),
    cashLimit: z.int().meta({ description: 'Plafond d’espèces détenues, en FCFA' }),
    guarantorName: z.string().nullable(),
    guarantorPhone: z.string().nullable(),
    emergencyContact: z.object({ name: z.string(), phone: z.string() }).nullable(),
    approvedAt: z.iso.datetime().nullable(),
    suspendedReason: z.string().nullable(),
    /** Dernière pièce envoyée pour chaque type. */
    documents: z.array(KycDocumentDto),
    /** Types de pièces encore à envoyer (absentes, refusées ou expirées). */
    missingDocuments: z.array(KycDocumentTypeEnum),
  })
  .meta({ id: 'RiderProfile' });

export const AdminRiderDto = RiderProfileDto.extend({
  user: z.object({
    id: z.uuid(),
    phone: z.string(),
    fullName: z.string().nullable(),
    /** Compte fermé à la demande du livreur (données personnelles effacées). */
    closed: z.boolean(),
  }),
  createdAt: z.iso.datetime(),
  /** Historique complet des pièces, de la plus récente à la plus ancienne. */
  documentHistory: z.array(KycDocumentDto),
  /** Pièces envoyées qui attendent l'examen de l'équipe. */
  pendingDocuments: z.int(),
  /** Pièces validées qui expirent dans les 30 jours (le livreur est déjà prévenu, A5). */
  expiringSoon: z.array(z.object({ type: KycDocumentTypeEnum, expiresOn: z.iso.date() })),
  /** Note moyenne donnée par les expéditeurs (1 à 5), depuis l'inscription. */
  rating: z.object({ average: z.number().nullable(), count: z.int() }),
  /** Courses livrées dans les 30 derniers jours. */
  deliveredLast30Days: z.int(),
  /** Suspendu faute d'avoir déposé ses anciennes espèces (réactivation par la finance). */
  cashSuspendedAt: z.iso.datetime().nullable(),
}).meta({ id: 'AdminRider' });

/** Vues de la liste : à examiner (candidature ou pièce en attente), puis par statut. */
export const AdminRiderViewEnum = z
  .enum(['TO_REVIEW', 'PENDING', 'ACTIVE', 'SUSPENDED', 'REJECTED', 'ALL'])
  .meta({ id: 'AdminRiderView' });

export const AdminRiderListQuery = PageQuery.extend({
  /** Ancien filtre, gardé : prime sur `view`. */
  status: RiderStatusEnum.optional(),
  view: AdminRiderViewEnum.default('ALL'),
  /** Nom, numéro de téléphone ou plaque (2 caractères au moins). */
  q: z.string().trim().min(2).max(60).optional(),
});

export const AdminRiderPageDto = z
  .object({
    items: z.array(AdminRiderDto),
    nextCursor: z.uuid().nullable(),
    /** Nombre de livreurs dans chaque vue (sans la recherche). */
    counts: z.object({
      TO_REVIEW: z.int(),
      PENDING: z.int(),
      ACTIVE: z.int(),
      SUSPENDED: z.int(),
      REJECTED: z.int(),
      ALL: z.int(),
    }),
  })
  .meta({ id: 'AdminRiderPage' });

/** Activité d'un livreur sur une période : de quoi juger sa fiabilité (H3). */
const ReliabilityWindowDto = z.object({
  /** Propositions de course : acceptées, refusées, laissées sans réponse. */
  offers: z.object({ accepted: z.int(), declined: z.int(), expired: z.int() }),
  /** Livrées (dont à l'heure), échecs déclarés, colis refusés à l'enlèvement. */
  deliveries: z.object({
    delivered: z.int(),
    onTime: z.int(),
    failed: z.int(),
    parcelsRefused: z.int(),
  }),
  rating: z.object({ average: z.number().nullable(), count: z.int() }),
  onlineMinutes: z.int(),
  /** Alertes de course : action loin de l'adresse, long arrêt, position simulée, coupure. */
  courseAlerts: z.int(),
  /** Alertes de sécurité déclenchées (hors alertes annulées). */
  sosAlerts: z.int(),
  /** Courses retirées faute de signal du téléphone avant l'enlèvement. */
  silentWithdrawals: z.int(),
});

export const RiderHistoryActionEnum = z
  .enum([
    'APPLIED',
    'DOCUMENT_APPROVED',
    'DOCUMENT_REJECTED',
    'APPROVED',
    'REJECTED',
    'SUSPENDED',
    'REACTIVATED',
    'CASH_OVERDUE',
    'CASH_SUSPENDED',
    'FREE_PAYOUT_SET',
  ])
  .meta({ id: 'RiderHistoryAction' });

export const RiderReliabilityDto = z
  .object({
    last30Days: ReliabilityWindowDto,
    allTime: ReliabilityWindowDto,
    /** Décisions et événements du compte, du plus récent au plus ancien (50 au plus). */
    history: z.array(
      z.object({
        at: z.iso.datetime(),
        action: RiderHistoryActionEnum,
        /** Membre de l'équipe ; null pour une action automatique. */
        by: z.string().nullable(),
        note: z.string().nullable(),
        documentType: KycDocumentTypeEnum.nullable(),
      }),
    ),
  })
  .meta({ id: 'RiderReliability' });

export const ReviewDocumentBody = z
  .object({
    decision: z.enum(['APPROVED', 'REJECTED']),
    rejectionReason: z.string().trim().min(3).max(300).optional(),
    expiresOn: z.iso.date().optional(),
  })
  .refine((body) => body.decision === 'APPROVED' || body.rejectionReason, {
    message: 'motif obligatoire pour un refus',
    path: ['rejectionReason'],
  });

export const RiderDecisionBody = z
  .object({
    decision: z.enum(['APPROVE', 'REJECT', 'SUSPEND', 'REACTIVATE']),
    reason: z.string().trim().min(3).max(300).optional(),
  })
  .refine((body) => !['REJECT', 'SUSPEND'].includes(body.decision) || body.reason, {
    message: 'motif obligatoire pour un refus ou une suspension',
    path: ['reason'],
  });
