import { Injectable } from '@nestjs/common';
import type { Request } from 'express';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { OtpService } from '../auth/otp.service.js';
import { AppError } from '../common/errors/app-error.js';
import type { AppLocale } from '../common/i18n/locale.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { LegalDocumentName } from './legal-sources.js';
import { LEGAL_TEXTS } from './legal-texts.generated.js';
import { APP_TERMS, currentVersion, type LegalApp, requiredVersions } from './legal-versions.js';

export { APP_TERMS, currentVersion, type LegalApp } from './legal-versions.js';

/** Preuve de l'acceptation : adresse IP, navigateur ou app, installation de l'app. */
export interface AcceptanceEvidence {
  ip?: string | undefined;
  userAgent?: string | undefined;
  installationId?: string | undefined;
}

interface Required {
  document: LegalDocumentName;
  version: string;
}

/**
 * Conditions d'utilisation et politique de confidentialité : textes en vigueur, acceptation
 * « signée » (case cochée dans l'app, puis code SMS), preuve conservée, nouvelle version à
 * accepter avant de commander (expéditeurs) ou de prendre des courses (livreurs).
 */
@Injectable()
export class LegalService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly audit: AuditService,
  ) {}

  document(name: LegalDocumentName) {
    const text = LEGAL_TEXTS[name];
    return { document: name, version: text.version, title: text.title, markdown: text.markdown };
  }

  /** Textes de l'app que l'utilisateur n'a pas encore acceptés dans leur version en vigueur. */
  async required(userId: string, app: LegalApp): Promise<Required[]> {
    const accepted = await this.prisma.consent.findMany({
      where: {
        userId,
        kind: { in: ['TERMS', 'PRIVACY'] },
        version: { in: requiredVersions(app) },
        granted: true,
      },
      select: { version: true },
    });
    const versions = new Set(accepted.map((consent) => consent.version));
    return [APP_TERMS[app], 'confidentialite' as const]
      .filter((document) => !versions.has(currentVersion(document)))
      .map((document) => ({ document, version: LEGAL_TEXTS[document].version }));
  }

  /** Bloque l'action tant que les conditions en vigueur de l'app ne sont pas acceptées. */
  async assertAccepted(userId: string, app: LegalApp): Promise<void> {
    if ((await this.required(userId, app)).length > 0) {
      throw AppError.forbidden('TERMS_ACCEPTANCE_REQUIRED');
    }
  }

  /** Dernières versions acceptées (copie consultable dans l'app). */
  async accepted(userId: string) {
    const rows = await this.prisma.consent.findMany({
      where: { userId, kind: { in: ['TERMS', 'PRIVACY'] }, granted: true },
      orderBy: { createdAt: 'desc' },
    });
    const seen = new Set<string>();
    const result: { document: string; version: string; acceptedAt: string }[] = [];
    for (const row of rows) {
      const [document, version] = row.version.split(':');
      if (!document || !version || seen.has(document)) continue;
      seen.add(document);
      result.push({ document, version, acceptedAt: row.createdAt.toISOString() });
    }
    return result;
  }

  /** Code SMS de signature : gardé pour les anciennes versions des apps. */
  requestCode(user: AuthUser, locale: AppLocale, ip: string | undefined) {
    return this.otp.request(user.phone, locale, ip, 'TERMS');
  }

  /**
   * Acceptation d'une nouvelle version par l'utilisateur connecté : textes lus jusqu'en bas
   * et case cochée dans l'app, versions envoyées (celles affichées) en vigueur. La session
   * suffit : le numéro a été vérifié par code SMS à l'inscription. Un code envoyé par une
   * ancienne app est encore vérifié. Preuve gardée sur le consentement et au journal d'audit.
   */
  async accept(
    user: AuthUser,
    app: LegalApp,
    body: { challengeId?: string; code?: string; versions: Record<string, string> },
    evidence: AcceptanceEvidence,
    request: Request,
  ): Promise<void> {
    const required = await this.required(user.id, app);
    for (const item of required) {
      if (body.versions[item.document] !== item.version) {
        throw AppError.conflict('TERMS_OUTDATED');
      }
    }
    const method = body.challengeId && body.code ? 'sms' : 'session';
    if (body.challengeId && body.code) {
      await this.otp.confirm(user.phone, body.challengeId, body.code, 'TERMS');
    }
    if (required.length === 0) return;
    await this.prisma.consent.createMany({
      data: required.map((item) => ({
        userId: user.id,
        kind: item.document === 'confidentialite' ? ('PRIVACY' as const) : ('TERMS' as const),
        version: currentVersion(item.document),
        granted: true,
        ip: evidence.ip ?? null,
        userAgent: evidence.userAgent?.slice(0, 300) ?? null,
        installationId: evidence.installationId ?? null,
      })),
    });
    await this.audit.record({
      actor: user,
      action: 'terms.accepted',
      entityType: 'user',
      entityId: user.id,
      after: { versions: required.map((item) => currentVersion(item.document)), method },
      request,
    });
  }
}
