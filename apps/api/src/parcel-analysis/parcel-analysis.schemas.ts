import { z } from 'zod';
import { PackageContentsEnum } from '../orders/orders.schemas.js';
import { PackageSizeEnum } from '../pricing/pricing.schemas.js';
import { PROHIBITED_CATEGORIES, type ParcelVerdict } from './parcel-vision.js';

export const AnalyzeParcelBody = z.object({
  /** Photo envoyée avant par POST /media avec kind=PARCEL_PHOTO. */
  photoKey: z.string().min(1).max(200),
});

export const ProhibitedCategoryEnum = z
  .enum(PROHIBITED_CATEGORIES)
  .meta({ id: 'ProhibitedCategory' });

/** Libellés des objets interdits (conditions des expéditeurs, article 4). */
export const PROHIBITED_LABELS: Record<(typeof PROHIBITED_CATEGORIES)[number], string> = {
  WEAPON: 'arme ou munitions',
  DRUGS: 'drogue',
  DANGEROUS_GOODS: 'matière dangereuse (gaz, carburant…)',
  LIVE_ANIMAL: 'animal vivant',
  CASH: 'liasses d’argent',
};

export const ParcelAnalysisDto = z
  .object({
    photoKey: z.string(),
    /** Faux : la photo ne montre pas de colis (à reprendre). */
    isParcel: z.boolean(),
    /** Proposition à confirmer ou corriger par l'expéditeur. */
    suggestion: z.object({
      size: PackageSizeEnum,
      contents: PackageContentsEnum,
      description: z.string().nullable(),
      fragile: z.boolean(),
    }),
    /** Objets interdits que la photo semble montrer. */
    prohibited: z.array(z.object({ code: ProhibitedCategoryEnum, label: z.string() })),
    confidence: z.enum(['low', 'medium', 'high']),
  })
  .meta({ id: 'ParcelAnalysis' });

export function toAnalysisDto(
  photoKey: string,
  verdict: ParcelVerdict,
): z.output<typeof ParcelAnalysisDto> {
  const description = verdict.description.trim().slice(0, 120);
  return {
    photoKey,
    isParcel: verdict.is_parcel,
    suggestion: {
      size: verdict.size,
      contents: verdict.contents,
      description: description || null,
      fragile: verdict.fragile,
    },
    prohibited: [...new Set(verdict.prohibited)].map((code) => ({
      code,
      label: PROHIBITED_LABELS[code],
    })),
    confidence: verdict.confidence,
  };
}

/** Avertissement gardé sur la commande : les objets interdits que la photo semble montrer. */
export function prohibitedWarning(result: unknown): string | null {
  const parsed = z.object({ prohibited: z.array(ProhibitedCategoryEnum) }).safeParse(result);
  if (!parsed.success || parsed.data.prohibited.length === 0) return null;
  return [...new Set(parsed.data.prohibited)].map((code) => PROHIBITED_LABELS[code]).join(', ');
}
