import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { renderSms } from '../common/i18n/sms-templates.js';
import { addDays, CAMEROON_TIME_ZONE, cameroonDate } from '../common/time.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SMS_PROVIDER, type SmsProvider } from '../sms/sms.provider.js';
import { DOCUMENT_LABELS } from './riders.schemas.js';

/** Jours avant expiration auxquels le livreur est prévenu (A5). */
export const REMINDER_DAYS = [30, 7, 1];

/**
 * Suivi quotidien des pièces des livreurs (A5) : les pièces dont la date est dépassée
 * passent en EXPIRED (le livreur n'est alors plus proposé, D4) et un SMS prévient le
 * livreur 30, 7 et 1 jours avant l'échéance.
 */
@Injectable()
export class KycExpiryService {
  private readonly logger = new Logger(KycExpiryService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  @Cron('0 7 * * *', { name: 'kyc-expiry', timeZone: CAMEROON_TIME_ZONE })
  async scheduled(): Promise<void> {
    if (!this.env.JOBS_ENABLED) return;
    const result = await this.run(new Date());
    this.logger.log(`Pièces expirées : ${result.expired}, rappels envoyés : ${result.reminded}`);
  }

  async run(now: Date): Promise<{ expired: number; reminded: number }> {
    const today = new Date(`${cameroonDate(now)}T00:00:00Z`);

    const { count: expired } = await this.prisma.kycDocument.updateMany({
      where: { status: 'APPROVED', expiresOn: { lt: today } },
      data: { status: 'EXPIRED' },
    });

    const reminderDates = REMINDER_DAYS.map((days) => addDays(today, days));
    const expiring = await this.prisma.kycDocument.findMany({
      where: { status: 'APPROVED', expiresOn: { in: reminderDates } },
      include: { rider: { include: { user: true, documents: true } } },
    });

    let reminded = 0;
    for (const doc of expiring) {
      // Une pièce plus récente du même type a déjà été envoyée : pas de rappel.
      const renewed = doc.rider.documents.some(
        (other) =>
          other.type === doc.type &&
          other.createdAt > doc.createdAt &&
          (other.status === 'PENDING' || other.status === 'APPROVED'),
      );
      if (renewed || !doc.expiresOn) continue;
      const locale = doc.rider.user.locale === 'EN' ? 'en' : 'fr';
      try {
        await this.sms.send(
          doc.rider.user.phone,
          renderSms('KYC_DOCUMENT_EXPIRING', locale, {
            document: DOCUMENT_LABELS[doc.type][locale],
            date: doc.expiresOn.toISOString().slice(0, 10),
          }),
        );
        reminded += 1;
      } catch (error) {
        this.logger.error(`Rappel d'expiration non envoyé (pièce ${doc.id})`, error);
      }
    }
    return { expired, reminded };
  }
}
