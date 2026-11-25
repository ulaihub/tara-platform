import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { addDays, CAMEROON_TIME_ZONE } from '../common/time.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../storage/object-storage.js';
import { maskOrdersWhere } from './masking.js';

/** Durée de conservation des données personnelles hors besoin opérationnel (cahier des charges). */
export const RETENTION_DAYS = 30;
/**
 * Photos de preuve et du colis, demandes au support closes, pièces des livreurs refusés :
 * 90 jours (choix du porteur du projet, 13 novembre 2026), comme les trajets des courses.
 */
export const MEDIA_RETENTION_DAYS = 90;
const BATCH = 500;

/** Commande visée par un litige ou un incident encore ouvert : ses preuves sont gardées. */
function openCase(orderId: Prisma.Sql): Prisma.Sql {
  return Prisma.sql`(
    EXISTS (SELECT 1 FROM tickets t WHERE t.order_id = ${orderId} AND t.status IN ('OPEN', 'IN_PROGRESS'))
    OR EXISTS (SELECT 1 FROM safety_alerts s WHERE s.order_id = ${orderId} AND s.resolved_at IS NULL)
    OR EXISTS (SELECT 1 FROM course_alerts a WHERE a.order_id = ${orderId} AND a.acknowledged_at IS NULL))`;
}

export interface RetentionReport {
  orderMessagesDeleted: number;
  ordersMasked: number;
  notificationsMasked: number;
  notificationSecretsPurged: number;
  locationLinksMasked: number;
  pendingDeliveriesDeleted: number;
  otpChallengesDeleted: number;
  refreshTokensDeleted: number;
  photosDeleted: number;
  ticketsDeleted: number;
  kycDocumentsDeleted: number;
}

/**
 * Minimisation des données (loi n° 2024/017), chaque nuit à 3 h :
 * - commandes terminées depuis plus de 30 jours : coordonnées du destinataire masquées ;
 * - SMS envoyés et liens de localisation de plus de 30 jours : numéro et nom effacés ;
 * - codes SMS et sessions expirées depuis plus de 30 jours : supprimés ;
 * - photos de preuve et du colis de plus de 90 jours : effacées, sauf litige ou incident
 *   ouvert sur la commande ;
 * - demandes au support closes depuis plus de 90 jours : supprimées avec leurs messages ;
 * - pièces d'identité d'un livreur refusé depuis plus de 90 jours : effacées.
 * Les données financières et le journal d'audit sont conservés (obligations légales).
 */
@Injectable()
export class RetentionService {
  private readonly logger = new Logger(RetentionService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
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
    // Colis d'un envoi en masse qui attendaient une adresse : partis, retirés ou oubliés.
    const pendingDeliveriesDeleted = await this.prisma.$executeRaw`
      DELETE FROM pending_deliveries WHERE created_at < ${cutoff}`;
    const otpChallengesDeleted = await this.prisma.$executeRaw`
      DELETE FROM otp_challenges WHERE created_at < ${cutoff}`;
    const refreshTokensDeleted = await this.prisma.$executeRaw`
      DELETE FROM refresh_tokens WHERE expires_at < ${cutoff} OR revoked_at < ${cutoff}`;
    const longCutoff = addDays(now, -MEDIA_RETENTION_DAYS);
    // Messages entre l'expéditeur et le livreur : utiles pour un litige, pas au-delà.
    const orderMessagesDeleted = await this.prisma.$executeRaw`
      DELETE FROM order_messages WHERE created_at < ${longCutoff}`;
    return {
      orderMessagesDeleted,
      ordersMasked,
      notificationsMasked,
      notificationSecretsPurged,
      locationLinksMasked,
      pendingDeliveriesDeleted,
      otpChallengesDeleted,
      refreshTokensDeleted,
      photosDeleted: await this.purgePhotos(longCutoff),
      ticketsDeleted: await this.purgeTickets(longCutoff),
      kycDocumentsDeleted: await this.purgeRejectedKyc(longCutoff),
    };
  }

  /** Photos de preuve et du colis (y compris celles jamais rattachées à une commande). */
  private async purgePhotos(cutoff: Date): Promise<number> {
    let deleted = 0;
    for (;;) {
      const rows = await this.prisma.$queryRaw<{ id: string; storage_key: string }[]>`
        SELECT m.id, m.storage_key FROM media_files m
         WHERE m.kind IN ('PROOF_PHOTO', 'PARCEL_PHOTO') AND m.created_at < ${cutoff}
           AND NOT EXISTS (SELECT 1 FROM delivery_proofs p
                            WHERE p.photo_key = m.storage_key AND ${openCase(Prisma.raw('p.order_id'))})
           AND NOT EXISTS (SELECT 1 FROM orders o
                            WHERE o.parcel_photo_key = m.storage_key AND ${openCase(Prisma.raw('o.id'))})
         ORDER BY m.created_at
         LIMIT ${BATCH}`;
      for (const row of rows) {
        if (!(await this.deleteFile(row.storage_key))) return deleted;
        // SQL direct : la date de mise à jour de la commande ne bouge pas.
        await this.prisma.$transaction([
          this.prisma
            .$executeRaw`UPDATE delivery_proofs SET photo_key = NULL WHERE photo_key = ${row.storage_key}`,
          this.prisma
            .$executeRaw`UPDATE orders SET parcel_photo_key = NULL WHERE parcel_photo_key = ${row.storage_key}`,
          this.prisma.parcelAnalysis.deleteMany({ where: { photoKey: row.storage_key } }),
          this.prisma.mediaFile.delete({ where: { id: row.id } }),
        ]);
        deleted += 1;
      }
      if (rows.length < BATCH) return deleted;
    }
  }

  /** Demandes au support résolues ou fermées depuis plus de 90 jours, pièces jointes comprises. */
  private async purgeTickets(cutoff: Date): Promise<number> {
    const tickets = await this.prisma.ticket.findMany({
      where: {
        status: { in: ['RESOLVED', 'CLOSED'] },
        OR: [{ resolvedAt: { lt: cutoff } }, { resolvedAt: null, updatedAt: { lt: cutoff } }],
      },
      select: { id: true, messages: { select: { attachmentKeys: true } } },
      take: BATCH,
    });
    const deletable: string[] = [];
    for (const ticket of tickets) {
      const keys = ticket.messages.flatMap((message) => message.attachmentKeys);
      let ok = true;
      for (const key of keys) ok = (await this.deleteFile(key)) && ok;
      if (!ok) continue;
      await this.prisma.mediaFile.deleteMany({ where: { storageKey: { in: keys } } });
      deletable.push(ticket.id);
    }
    const { count } = await this.prisma.ticket.deleteMany({ where: { id: { in: deletable } } });
    return count;
  }

  /** Pièces d'identité d'un livreur refusé depuis plus de 90 jours (il pourra recommencer). */
  private async purgeRejectedKyc(cutoff: Date): Promise<number> {
    const documents = await this.prisma.kycDocument.findMany({
      where: { rider: { status: 'REJECTED', updatedAt: { lt: cutoff } } },
      select: { id: true, storageKey: true },
      take: BATCH,
    });
    let deleted = 0;
    for (const document of documents) {
      if (!(await this.deleteFile(document.storageKey))) continue;
      await this.prisma.$transaction([
        this.prisma.mediaFile.deleteMany({ where: { storageKey: document.storageKey } }),
        this.prisma.kycDocument.delete({ where: { id: document.id } }),
      ]);
      deleted += 1;
    }
    return deleted;
  }

  /** Efface un fichier ; en cas d'échec, la base n'est pas touchée (nouvel essai la nuit suivante). */
  private async deleteFile(key: string): Promise<boolean> {
    try {
      await this.storage.delete(key);
      return true;
    } catch (error) {
      this.logger.warn(`Fichier non effacé (${key}) : ${String(error)}`);
      return false;
    }
  }
}
