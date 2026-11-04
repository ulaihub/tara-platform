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
  user: z.object({ id: z.uuid(), phone: z.string(), fullName: z.string().nullable() }),
  createdAt: z.iso.datetime(),
  /** Historique complet des pièces, de la plus récente à la plus ancienne. */
  documentHistory: z.array(KycDocumentDto),
}).meta({ id: 'AdminRider' });

export const AdminRiderListQuery = PageQuery.extend({ status: RiderStatusEnum.optional() });

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
