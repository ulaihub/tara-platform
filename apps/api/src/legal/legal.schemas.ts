import { z } from 'zod';
import { LEGAL_SOURCES } from './legal-sources.js';

export const LegalDocumentEnum = z.enum(
  Object.keys(LEGAL_SOURCES) as [keyof typeof LEGAL_SOURCES, ...(keyof typeof LEGAL_SOURCES)[]],
);

export const LegalDocumentDto = z
  .object({
    document: LegalDocumentEnum,
    /** « 2026-11 » : la version à afficher et à renvoyer à l'acceptation. */
    version: z.string(),
    title: z.string(),
    /** Texte complet (titres « # », listes « - », tableaux, gras « ** »). */
    markdown: z.string(),
  })
  .meta({ id: 'LegalDocument' });

/** Versions affichées par l'app et acceptées, par document : `{ "expediteurs": "2026-11" }`. */
export const AcceptedVersions = z
  .partialRecord(LegalDocumentEnum, z.string().max(16))
  .meta({ id: 'AcceptedVersions' });

export const TermsAppQuery = z.object({ app: z.enum(['client', 'rider']) });

export const TermsStatusDto = z
  .object({
    /** Textes à accepter avant de continuer (vide si tout est accepté). */
    required: z.array(z.object({ document: LegalDocumentEnum, version: z.string() })),
    /** Dernières versions acceptées, avec leur date (copie consultable). */
    accepted: z.array(
      z.object({ document: z.string(), version: z.string(), acceptedAt: z.iso.datetime() }),
    ),
  })
  .meta({ id: 'TermsStatus' });

export const AcceptTermsBody = z
  .object({
    /**
     * Code SMS : facultatif. La session de l'utilisateur connecté suffit ; les anciennes
     * versions des apps envoient encore un code, vérifié s'il est là.
     */
    challengeId: z.uuid().optional(),
    code: z
      .string()
      .regex(/^\d{6}$/)
      .optional(),
    /** Versions affichées par l'app : refusées si elles ne sont plus en vigueur. */
    versions: AcceptedVersions,
    /** Installation de l'app qui accepte (preuve). */
    installationId: z.string().min(8).max(64).optional(),
  })
  .refine((body) => (body.challengeId === undefined) === (body.code === undefined), {
    message: 'challengeId et code vont ensemble',
    path: ['code'],
  });
