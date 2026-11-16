import { createHmac, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { OtpService } from '../auth/otp.service.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { sha256 } from '../common/crypto.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { PinProof } from './pin.schemas.js';

const scryptAsync = promisify(scrypt) as (
  password: Buffer,
  salt: Buffer,
  keylen: number,
  options: { N: number; r: number; p: number; maxmem: number },
) => Promise<Buffer>;

/** Erreurs tolérées avant blocage (Orange Money en tolère 3, MTN MoMo 3 à 5). */
export const MAX_PIN_FAILURES = 5;
const SCRYPT = { N: 2 ** 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

/**
 * Codes trop faciles à deviner : quatre chiffres identiques ou une suite (1234, 9876…).
 * Ce sont les premiers essayés par quelqu'un qui prend le téléphone.
 */
export function tooSimplePin(pin: string): boolean {
  const digits = pin.split('').map(Number);
  const steps = digits.slice(1).map((digit, i) => digit - (digits[i] as number));
  return (
    steps.every((step) => step === 0) ||
    steps.every((step) => step === 1) ||
    steps.every((step) => step === -1)
  );
}

/**
 * Code secret à 4 chiffres, comme Orange Money et MTN MoMo : demandé pour voir le solde,
 * retirer de l'argent et supprimer le compte. L'empreinte digitale peut le remplacer sur un
 * téléphone où il a été tapé une fois. Après 5 erreurs, il est bloqué : on en choisit un
 * nouveau avec un code reçu par SMS ou WhatsApp, preuve que l'on a toujours le numéro.
 *
 * Haché avec scrypt et le secret du serveur : une copie de la base ne suffit pas à le
 * retrouver, même en essayant les 10 000 codes possibles.
 */
@Injectable()
export class PinService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private async derive(userId: string, pin: string, salt: Buffer): Promise<Buffer> {
    const peppered = createHmac('sha256', this.env.CODE_HASH_SECRET)
      .update(`pin:${userId}:${pin}`)
      .digest();
    return scryptAsync(peppered, salt, 32, SCRYPT);
  }

  private async hash(userId: string, pin: string): Promise<string> {
    const salt = randomBytes(16);
    const derived = await this.derive(userId, pin, salt);
    return `s1$${salt.toString('base64')}$${derived.toString('base64')}`;
  }

  private async matches(userId: string, pin: string, stored: string): Promise<boolean> {
    const [version, salt, expected] = stored.split('$');
    if (version !== 's1' || !salt || !expected) return false;
    const derived = await this.derive(userId, pin, Buffer.from(salt, 'base64'));
    const wanted = Buffer.from(expected, 'base64');
    return derived.length === wanted.length && timingSafeEqual(derived, wanted);
  }

  async status(
    userId: string,
  ): Promise<{ set: boolean; locked: boolean; remainingAttempts: number }> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { pinHash: true, pinLockedAt: true, pinFailedAttempts: true },
    });
    return {
      set: user.pinHash !== null,
      locked: user.pinLockedAt !== null,
      remainingAttempts: user.pinLockedAt ? 0 : MAX_PIN_FAILURES - user.pinFailedAttempts,
    };
  }

  /**
   * Contrôle la preuve d'une action sensible. Sans code secret choisi, l'action passe
   * (anciennes versions des apps) sauf si [required] ; sinon le code ou l'empreinte est exigé.
   * Une erreur compte un essai ; la cinquième bloque le code.
   */
  async assert(
    user: AuthUser,
    proof: PinProof,
    options: { required?: boolean; request?: Request } = {},
  ): Promise<void> {
    const row = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
      select: { pinHash: true, pinLockedAt: true },
    });
    if (!row.pinHash) {
      if (options.required) throw AppError.forbidden('PIN_NOT_SET');
      return;
    }
    if (row.pinLockedAt) throw AppError.forbidden('PIN_LOCKED');
    if (proof.biometricKey) {
      const key = await this.prisma.pinDeviceKey.findUnique({
        where: { keyHash: sha256(proof.biometricKey) },
        select: { userId: true },
      });
      if (key?.userId !== user.id) throw AppError.forbidden('BIOMETRIC_INVALID');
      return;
    }
    if (!proof.pin) throw AppError.forbidden('PIN_REQUIRED');
    if (await this.matches(user.id, proof.pin, row.pinHash)) {
      await this.prisma.user.updateMany({
        where: { id: user.id, pinFailedAttempts: { gt: 0 } },
        data: { pinFailedAttempts: 0 },
      });
      return;
    }
    // Compte l'erreur en une seule écriture (deux essais simultanés comptent pour deux).
    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: { pinFailedAttempts: { increment: 1 } },
      select: { pinFailedAttempts: true },
    });
    if (updated.pinFailedAttempts >= MAX_PIN_FAILURES) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { pinLockedAt: new Date() },
      });
      // Les empreintes de ce compte ne servent plus : le nouveau code les remplacera.
      await this.prisma.pinDeviceKey.deleteMany({ where: { userId: user.id } });
      await this.audit.record({
        actor: user,
        action: 'pin.locked',
        entityType: 'user',
        entityId: user.id,
        ...(options.request ? { request: options.request } : {}),
      });
      throw AppError.forbidden('PIN_LOCKED');
    }
    throw new AppError('PIN_INVALID', HttpStatus.FORBIDDEN, {
      remaining: MAX_PIN_FAILURES - updated.pinFailedAttempts,
    });
  }

  /**
   * Choix du code secret : le premier librement (compte connecté) ; ensuite avec le code
   * actuel, ou, s'il est oublié ou bloqué, avec un code reçu par SMS ou WhatsApp. Les
   * empreintes enregistrées sont effacées : elles se réactivent avec le nouveau code.
   */
  async set(
    user: AuthUser,
    body: { pin: string; currentPin?: string; challengeId?: string; code?: string },
    request: Request,
  ): Promise<void> {
    if (tooSimplePin(body.pin)) throw AppError.badRequest('PIN_TOO_SIMPLE');
    const row = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
      select: { pinHash: true },
    });
    let action = 'pin.set';
    if (body.challengeId && body.code) {
      await this.otp.confirm(user.phone, body.challengeId, body.code, 'PIN_RESET');
      action = 'pin.reset';
    } else if (row.pinHash) {
      if (!body.currentPin) throw AppError.forbidden('PIN_REQUIRED');
      await this.assert(user, { pin: body.currentPin }, { request });
      action = 'pin.changed';
    }
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: {
          pinHash: await this.hash(user.id, body.pin),
          pinSetAt: new Date(),
          pinFailedAttempts: 0,
          pinLockedAt: null,
        },
      }),
      this.prisma.pinDeviceKey.deleteMany({ where: { userId: user.id } }),
    ]);
    await this.audit.record({
      actor: user,
      action,
      entityType: 'user',
      entityId: user.id,
      request,
    });
  }

  /** Empreinte sur ce téléphone : le code est tapé une fois, une clé le remplace ensuite. */
  async enableBiometric(
    user: AuthUser,
    body: { pin: string; installationId: string },
    request: Request,
  ): Promise<{ key: string }> {
    await this.assert(user, { pin: body.pin }, { required: true, request });
    const key = randomBytes(32).toString('base64url');
    await this.prisma.pinDeviceKey.upsert({
      where: { userId_installationId: { userId: user.id, installationId: body.installationId } },
      create: { userId: user.id, installationId: body.installationId, keyHash: sha256(key) },
      update: { keyHash: sha256(key), createdAt: new Date() },
    });
    await this.audit.record({
      actor: user,
      action: 'pin.biometric_enabled',
      entityType: 'user',
      entityId: user.id,
      request,
    });
    return { key };
  }

  async disableBiometric(user: AuthUser, installationId: string): Promise<void> {
    await this.prisma.pinDeviceKey.deleteMany({ where: { userId: user.id, installationId } });
  }
}
