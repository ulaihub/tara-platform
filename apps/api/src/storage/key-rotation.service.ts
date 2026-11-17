import { Inject, Injectable } from '@nestjs/common';
import { MFA_KEY_PURPOSE } from '../auth/mfa.service.js';
import { decrypt, deriveKey, encrypt } from '../common/crypto.js';
import { ENV } from '../config/config.module.js';
import { BATCH_CODE_KEY_PURPOSE } from '../orders/batch-code.js';
import { type Env, storageKeys } from '../config/env.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from './object-storage.js';

export interface RotationCount {
  /** Déjà chiffrés avec la clé actuelle. */
  current: number;
  /** Rechiffrés avec la clé actuelle. */
  rotated: number;
  /** Illisibles avec les deux clés (ou absents) : à examiner, jamais modifiés. */
  failed: string[];
}

export interface RotationReport {
  files: RotationCount;
  totpSecrets: RotationCount;
  batchCodes: RotationCount;
}

const BATCH = 200;

/**
 * Rotation de STORAGE_ENCRYPTION_KEY (docs/SECURITE.md) : rechiffre avec la clé actuelle
 * tout ce qui l'est encore avec l'ancienne (STORAGE_ENCRYPTION_KEY_PREVIOUS) : fichiers
 * chiffrés (pièces d'identité) et secrets de double authentification de l'équipe. Peut être
 * relancée sans risque : ce qui est déjà à jour est laissé tel quel. Les secrets des
 * notifications en attente vivent quelques minutes et restent lisibles avec l'ancienne clé.
 */
@Injectable()
export class KeyRotationService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async rotate(log: (line: string) => void = () => undefined): Promise<RotationReport> {
    const [current, previous] = storageKeys(this.env);
    if (!current || !previous) {
      throw new Error('STORAGE_ENCRYPTION_KEY_PREVIOUS manquant : aucune ancienne clé à remplacer');
    }
    const files = await this.rotateFiles(current, previous, log);
    log(
      `Fichiers : ${files.rotated} rechiffrés, ${files.current} déjà à jour, ${files.failed.length} illisibles`,
    );
    const totpSecrets = await this.rotateTotp(
      deriveKey(current, MFA_KEY_PURPOSE),
      deriveKey(previous, MFA_KEY_PURPOSE),
    );
    log(
      `Secrets de double authentification : ${totpSecrets.rotated} rechiffrés, ${totpSecrets.current} déjà à jour, ${totpSecrets.failed.length} illisibles`,
    );
    const batchCodes = await this.rotateBatchCodes(
      deriveKey(current, BATCH_CODE_KEY_PURPOSE),
      deriveKey(previous, BATCH_CODE_KEY_PURPOSE),
    );
    log(
      `Codes d'enlèvement des envois en attente : ${batchCodes.rotated} rechiffrés, ${batchCodes.current} déjà à jour, ${batchCodes.failed.length} illisibles`,
    );
    return { files, totpSecrets, batchCodes };
  }

  private async rotateFiles(
    current: Buffer,
    previous: Buffer,
    log: (line: string) => void,
  ): Promise<RotationCount> {
    const count: RotationCount = { current: 0, rotated: 0, failed: [] };
    let after: string | undefined;
    for (;;) {
      const batch = await this.prisma.mediaFile.findMany({
        where: { encrypted: true, ...(after ? { id: { gt: after } } : {}) },
        orderBy: { id: 'asc' },
        take: BATCH,
        select: { id: true, storageKey: true },
      });
      if (batch.length === 0) return count;
      for (const file of batch) {
        let stored: Buffer;
        try {
          stored = await this.storage.get(file.storageKey);
        } catch {
          count.failed.push(file.storageKey);
          continue;
        }
        const plain = reencrypt(stored, current, previous);
        if (plain === 'current') count.current += 1;
        else if (plain === null) count.failed.push(file.storageKey);
        else {
          await this.storage.put(file.storageKey, plain);
          count.rotated += 1;
        }
      }
      after = batch.at(-1)?.id;
      log(`… ${count.current + count.rotated + count.failed.length} fichiers vus`);
    }
  }

  /** Code commun d'un envoi dont des colis attendent encore l'adresse de leur client. */
  private async rotateBatchCodes(current: Buffer, previous: Buffer): Promise<RotationCount> {
    const count: RotationCount = { current: 0, rotated: 0, failed: [] };
    const batches = await this.prisma.orderBatch.findMany({
      where: { pickupCodeSealed: { not: null } },
      select: { id: true, pickupCodeSealed: true },
    });
    for (const batch of batches) {
      const sealed = batch.pickupCodeSealed as string;
      const next = reencrypt(Buffer.from(sealed, 'base64'), current, previous);
      if (next === 'current') count.current += 1;
      else if (next === null) count.failed.push(batch.id);
      else {
        const { count: updated } = await this.prisma.orderBatch.updateMany({
          where: { id: batch.id, pickupCodeSealed: sealed },
          data: { pickupCodeSealed: next.toString('base64') },
        });
        if (updated === 1) count.rotated += 1;
      }
    }
    return count;
  }

  private async rotateTotp(current: Buffer, previous: Buffer): Promise<RotationCount> {
    const count: RotationCount = { current: 0, rotated: 0, failed: [] };
    const users = await this.prisma.user.findMany({
      where: { totpSecretEnc: { not: null } },
      select: { id: true, totpSecretEnc: true },
    });
    for (const user of users) {
      const sealed = user.totpSecretEnc as string;
      const next = reencrypt(Buffer.from(sealed, 'base64'), current, previous);
      if (next === 'current') count.current += 1;
      else if (next === null) count.failed.push(user.id);
      else {
        // Mise à jour conditionnelle : un secret changé entre-temps n'est pas écrasé.
        const { count: updated } = await this.prisma.user.updateMany({
          where: { id: user.id, totpSecretEnc: sealed },
          data: { totpSecretEnc: next.toString('base64') },
        });
        if (updated === 1) count.rotated += 1;
      }
    }
    return count;
  }
}

/**
 * Contenu rechiffré avec la clé actuelle ; « current » s'il l'est déjà ; null s'il n'est
 * lisible avec aucune des deux clés.
 */
export function reencrypt(
  payload: Buffer,
  current: Buffer,
  previous: Buffer,
): Buffer | 'current' | null {
  try {
    decrypt(current, payload);
    return 'current';
  } catch {
    // Pas encore rechiffré : essai avec l'ancienne clé.
  }
  try {
    return encrypt(current, decrypt(previous, payload));
  } catch {
    return null;
  }
}
