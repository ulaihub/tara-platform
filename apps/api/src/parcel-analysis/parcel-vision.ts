import Anthropic from '@anthropic-ai/sdk';
import { betaZodOutputFormat } from '@anthropic-ai/sdk/helpers/beta/zod';
import { z } from 'zod';

export const PARCEL_VISION = Symbol('PARCEL_VISION');

/** Objets interdits par les conditions des expéditeurs (article 4), tels que la photo les montre. */
export const PROHIBITED_CATEGORIES = [
  'WEAPON',
  'DRUGS',
  'DANGEROUS_GOODS',
  'LIVE_ANIMAL',
  'CASH',
] as const;

/** Verdict demandé au modèle : une proposition, que l'expéditeur confirme ou corrige. */
export const ParcelVerdict = z.object({
  /** La photo montre bien un objet à expédier (pas une personne, un écran, un paysage…). */
  is_parcel: z.boolean(),
  size: z.enum(['S', 'M', 'L', 'XL', 'BULKY']),
  contents: z.enum([
    'DOCUMENTS',
    'CLOTHING',
    'MEDICINE',
    'LAUNDRY',
    'HOUSEHOLD',
    'ELECTRONICS',
    'FOOD',
    'BEAUTY',
    'SECONDHAND',
    'OTHER',
  ]),
  /** Ce que l'on voit, en français, en quelques mots (« Réfrigérateur 2 portes »). */
  description: z.string(),
  fragile: z.boolean(),
  prohibited: z.array(z.enum(PROHIBITED_CATEGORIES)),
  confidence: z.enum(['low', 'medium', 'high']),
});
export type ParcelVerdict = z.infer<typeof ParcelVerdict>;

export interface ParcelImage {
  buffer: Buffer;
  mimeType: string;
}

/** Le moteur d'analyse n'a pas pu répondre (indisponible, refus, réponse illisible). */
export class ParcelVisionUnavailableError extends Error {}

export interface ParcelVision {
  /** « claude:<modèle> » ou « fake » : gardé avec chaque analyse. */
  readonly engine: string;
  analyze(image: ParcelImage): Promise<ParcelVerdict>;
}

/**
 * Consignes du modèle. Stables d'un appel à l'autre ; elles décrivent les tailles et les
 * natures exactement comme l'app les présente à l'expéditeur.
 */
export const PARCEL_SYSTEM_PROMPT = `Tu aides Tara, un service de livraison à Douala (Cameroun), à décrire le colis qu'un expéditeur s'apprête à envoyer, à partir d'une seule photo. Ta réponse est une proposition : l'expéditeur la vérifie avant de commander.

Taille (choisis la plus petite qui convient ; le livreur transporte S à XL à moto, BULKY en tricycle) :
- S : jusqu'à 2 kg, tient dans une main (enveloppe, téléphone, boîte de médicaments).
- M : jusqu'à 5 kg (boîte à chaussures, petit sac de vêtements).
- L : jusqu'à 10 kg (carton moyen, sac de linge).
- XL : jusqu'à 20 kg (gros carton, petit électroménager : micro-ondes, ventilateur).
- BULKY : trop grand ou trop lourd pour une moto (réfrigérateur, cuisinière, machine à laver, matelas, meuble, téléviseur de plus de 43 pouces).

Nature du contenu : DOCUMENTS, CLOTHING (vêtements, chaussures), MEDICINE, LAUNDRY (linge), HOUSEHOLD (cuisine, maison, électroménager, meubles), ELECTRONICS, FOOD, BEAUTY, SECONDHAND (brocante), OTHER.

fragile : vrai pour le verre, la vaisselle, les écrans, l'électronique et l'électroménager, les gâteaux.

prohibited : ne signale une catégorie que si l'objet est clairement visible sur la photo, jamais par supposition (un carton fermé ne prouve rien) :
- WEAPON : arme à feu, munitions, machette ou couteau de combat ;
- DRUGS : drogue visible ;
- DANGEROUS_GOODS : bouteille de gaz, bidon de carburant, produit inflammable, explosif ou corrosif ;
- LIVE_ANIMAL : animal vivant ;
- CASH : liasses de billets.

description : en français, 2 à 6 mots sur l'objet lui-même (« Réfrigérateur 2 portes », « Carton de vêtements »). Ne décris jamais une personne présente sur la photo, ni ce qui permettrait de l'identifier.

is_parcel : faux si la photo ne montre pas un objet à expédier (personne seule, capture d'écran, photo floue ou noire) ; propose alors S, OTHER, une description vide et confidence low.

confidence : high si l'objet est net et reconnaissable, medium s'il est en partie caché ou emballé, low sinon.`;

export interface ClaudeParcelVisionConfig {
  apiKey: string;
  model: string;
  /** Client injecté (tests). */
  client?: Anthropic;
}

/**
 * Analyse par Claude (vision + sortie structurée). Effort bas : c'est une classification
 * courte ; un refus du modèle est repris automatiquement par le modèle de repli conseillé
 * par Anthropic (fallbacks « default »).
 */
export class ClaudeParcelVision implements ParcelVision {
  readonly engine: string;
  private readonly client: Anthropic;

  constructor(private readonly config: ClaudeParcelVisionConfig) {
    this.engine = `claude:${config.model}`;
    this.client =
      config.client ?? new Anthropic({ apiKey: config.apiKey, timeout: 60_000, maxRetries: 2 });
  }

  async analyze(image: ParcelImage): Promise<ParcelVerdict> {
    const mediaType = image.mimeType as 'image/jpeg' | 'image/png' | 'image/webp';
    let response;
    try {
      response = await this.client.beta.messages.parse({
        model: this.config.model,
        max_tokens: 4000,
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        output_config: { effort: 'low', format: betaZodOutputFormat(ParcelVerdict) },
        system: PARCEL_SYSTEM_PROMPT,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: mediaType,
                  data: image.buffer.toString('base64'),
                },
              },
              { type: 'text', text: 'Voici la photo du colis à expédier.' },
            ],
          },
        ],
      });
    } catch (error) {
      if (error instanceof Anthropic.APIError) {
        throw new ParcelVisionUnavailableError(`Claude ${error.status ?? '?'} : ${error.message}`);
      }
      throw new ParcelVisionUnavailableError(`Claude injoignable : ${String(error)}`);
    }
    if (response.stop_reason === 'refusal') {
      throw new ParcelVisionUnavailableError('Analyse refusée par le modèle');
    }
    if (!response.parsed_output) {
      throw new ParcelVisionUnavailableError(`Réponse illisible (${response.stop_reason ?? '?'})`);
    }
    return response.parsed_output;
  }
}

/**
 * Moteur factice (développement, tests, ville de démonstration) : rien n'est envoyé hors du
 * serveur. Les tests fixent la prochaine réponse ou une panne.
 */
export class FakeParcelVision implements ParcelVision {
  readonly engine = 'fake';
  readonly calls: ParcelImage[] = [];
  next: ParcelVerdict | Error | null = null;

  analyze(image: ParcelImage): Promise<ParcelVerdict> {
    this.calls.push(image);
    const next = this.next;
    this.next = null;
    if (next instanceof Error) return Promise.reject(next);
    return Promise.resolve(
      next ?? {
        is_parcel: true,
        size: 'M',
        contents: 'OTHER',
        description: 'Carton fermé',
        fragile: false,
        prohibited: [],
        confidence: 'medium',
      },
    );
  }
}
