import { z } from 'zod';

export const LandmarkDto = z
  .object({
    id: z.uuid(),
    name: z.string(),
    latitude: z.number(),
    longitude: z.number(),
  })
  .meta({ id: 'Landmark' });

export const LandmarkListDto = z
  .object({
    /** Change quand un repère est ajouté ou retiré : l'app ne recharge que si besoin. */
    version: z.string(),
    items: z.array(LandmarkDto),
  })
  .meta({ id: 'LandmarkList' });

export const LandmarkBody = z.object({
  /** « Carrefour Nkongmondo », « Rond-point Deido », « Face Collège des Nations »… */
  name: z.string().trim().min(3).max(80),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});
