import { describe, expect, it } from 'vitest';
import {
  approvalBlockers,
  documentLines,
  documentSummary,
  percent,
  rates,
  riderView,
} from '@/lib/riders';
import type { AdminRider, KycDocument } from '@/lib/schemas';

const doc = (
  type: KycDocument['type'],
  status: KycDocument['status'],
  createdAt = '2026-11-01T08:00:00Z',
): KycDocument => ({
  id: `${type}-${status}-${createdAt}`,
  type,
  status,
  expiresOn: null,
  rejectionReason: null,
  createdAt,
  reviewedAt: null,
});

const ALL_APPROVED: KycDocument[] = [
  'NATIONAL_ID_FRONT',
  'NATIONAL_ID_BACK',
  'DRIVING_LICENSE',
  'VEHICLE_RENTAL_CONTRACT',
  'INSURANCE',
  'SELFIE',
  'CRIMINAL_RECORD',
].map((type) => doc(type as KycDocument['type'], 'APPROVED'));

function rider(overrides: Partial<AdminRider> = {}): AdminRider {
  return {
    id: 'r1',
    status: 'PENDING',
    vehicleType: 'MOTORBIKE',
    plateNumber: 'LT 123 AB',
    cashLimit: 25000,
    guarantorName: null,
    guarantorPhone: null,
    emergencyContact: null,
    approvedAt: null,
    suspendedReason: null,
    documents: ALL_APPROVED,
    missingDocuments: [],
    user: { id: 'u1', phone: '+237690000001', fullName: 'Ibrahim Nfor' },
    createdAt: '2026-11-01T08:00:00Z',
    documentHistory: ALL_APPROVED,
    pendingDocuments: 0,
    expiringSoon: [],
    rating: { average: null, count: 0 },
    deliveredLast30Days: 0,
    cashSuspendedAt: null,
    ...overrides,
  };
}

describe('livreurs au back-office', () => {
  it('ouvre « à examiner » par défaut et accepte la vue en minuscules', () => {
    expect(riderView(undefined)).toBe('TO_REVIEW');
    expect(riderView('suspended')).toBe('SUSPENDED');
    expect(riderView('nimporte')).toBe('TO_REVIEW');
  });

  it('montre chaque pièce exigée, le contrat de location valant carte grise', () => {
    const lines = documentLines([
      doc('SELFIE', 'REJECTED', '2026-11-01T08:00:00Z'),
      doc('SELFIE', 'PENDING', '2026-11-02T08:00:00Z'),
      doc('VEHICLE_RENTAL_CONTRACT', 'APPROVED'),
      doc('GUARANTOR_ID', 'APPROVED'),
    ]);
    expect(lines).toHaveLength(8);
    expect(lines[3]).toMatchObject({
      label: 'Carte grise ou Contrat de location',
      document: { type: 'VEHICLE_RENTAL_CONTRACT' },
    });
    expect(lines[5]?.document?.status).toBe('PENDING');
    expect(lines[0]?.document).toBeNull();
    expect(lines[7]).toMatchObject({ label: 'CNI du garant', required: false });
  });

  it('ne valide qu’avec toutes les pièces exigées validées', () => {
    expect(approvalBlockers(rider())).toEqual([]);
    expect(approvalBlockers(rider({ documents: ALL_APPROVED.slice(1) }))).toEqual([
      'Pièces validées : 6 sur 7',
    ]);
  });

  it('résume les pièces : à examiner d’abord, puis manquantes, puis échéance proche', () => {
    expect(documentSummary(rider({ pendingDocuments: 2 }))).toEqual({
      text: '2 à examiner',
      tone: 'text-warn',
    });
    expect(documentSummary(rider({ missingDocuments: ['SELFIE'] })).text).toBe('1 manquante');
    expect(
      documentSummary(rider({ expiringSoon: [{ type: 'INSURANCE', expiresOn: '2026-12-03' }] }))
        .text,
    ).toBe('Assurance expire le 3 déc. 2026');
    expect(documentSummary(rider()).text).toBe('Complètes');
  });

  it('calcule les taux sans diviser par zéro', () => {
    expect(percent(1, 3)).toBe(33);
    expect(percent(0, 0)).toBeNull();
    expect(
      rates({
        offers: { accepted: 3, declined: 1, expired: 1 },
        deliveries: { delivered: 2, onTime: 1, failed: 1, parcelsRefused: 1 },
        rating: { average: 4.5, count: 2 },
        onlineMinutes: 120,
        courseAlerts: 1,
        sosAlerts: 0,
      }),
    ).toEqual({ acceptance: 60, success: 67, onTime: 50 });
  });
});
