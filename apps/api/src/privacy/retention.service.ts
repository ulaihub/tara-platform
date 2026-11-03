import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { addDays, CAMEROON_TIME_ZONE } from '../common/time.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { maskOrdersWhere } from './masking.js';

/** Durée de conservation des données personnelles hors besoin opérationnel (cahier des charges). */
export const RETENTION_DAYS = 30;

export interface RetentionReport {
  ordersMasked: number;
  notificationsMasked: number;
  notificationSecretsPurged: number;
  locationLinksMasked: number;
  otpChallengesDeleted: number;
  refreshTokensDeleted: number;
}

/**
 * Minimisation des données (loi n° 2024/017), chaque nuit à 3 h :
 * - commandes terminées depuis plus de 30 jours : coordonnées du destinataire masquées ;
 * - SMS envoyés et liens de localisation de plus de 30 jours : numéro et nom effacés ;
 * - codes SMS et sessions expirées depuis plus de 30 jours : supprimés.
 * Les données financières et le journal d'audit sont conservés (obligations légales).
 */
@Injectable()
export class RetentionService {
  private readonly logger = new Logger(RetentionService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  @Cron('0 3 * * *', { name: 'data-retention', timeZone: CAMEROON_TIME_ZONE })
  async scheduled(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    const report = await this.run(new Date());
    this.logger.log(`Conservation des données : ${JSON.stringify(report)}`);
  }

  async run(now: Date): Promise<RetentionReport> {
    const cutoff = addDays(now, -RETENTION_DAYS);
    const ordersMasked = await maskOrdersWhere(
      this.prisma,
      Prisma.sql`status IN ('DELIVERED', 'RETURNED', 'CANCELLED') AND updated_at < ${cutoff}`,
    );
    const notificationsMasked = await this.prisma.$executeRaw`
      UPDATE notifications SET recipient_phone = NULL
       WHERE recipient_phone IS NOT NULL AND created_at < ${cutoff}`;
    // Codes de livraison gardés chiffrés pour un éventuel repli SMS : effacés après un jour.
    const notificationSecretsPurged = await this.prisma.$executeRaw`
      UPDATE notifications SET payload = payload - 'sealed'
       WHERE payload ? 'sealed' AND created_at < ${addDays(now, -1)}`;
    const locationLinksMasked = await this.prisma.$executeRaw`
      UPDATE location_links SET recipient_name = NULL, recipient_phone = NULL
       WHERE created_at < ${cutoff} AND (recipient_name IS NOT NULL OR recipient_phone IS NOT NULL)`;
    const otpChallengesDeleted = await this.prisma.$executeRaw`
      DELETE FROM otp_challenges WHERE created_at < ${cutoff}`;
    const refreshTokensDeleted = await this.prisma.$executeRaw`
      DELETE FROM refresh_tokens WHERE expires_at < ${cutoff} OR revoked_at < ${cutoff}`;
    return {
      ordersMasked,
      notificationsMasked,
      notificationSecretsPurged,
      locationLinksMasked,
      otpChallengesDeleted,
      refreshTokensDeleted,
    };
  }
}
