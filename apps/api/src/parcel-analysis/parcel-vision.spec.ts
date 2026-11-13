import Anthropic from '@anthropic-ai/sdk';
import {
  ClaudeParcelVision,
  PARCEL_SYSTEM_PROMPT,
  type ParcelVerdict,
  ParcelVisionUnavailableError,
} from './parcel-vision.js';

const verdict: ParcelVerdict = {
  is_parcel: true,
  size: 'BULKY',
  contents: 'HOUSEHOLD',
  description: 'Réfrigérateur 2 portes',
  fragile: true,
  prohibited: [],
  confidence: 'high',
};

/** Client Anthropic réduit à l'appel utilisé, qui garde la requête envoyée. */
function fakeClient(answer: () => Promise<unknown>): { client: Anthropic; sent: unknown[] } {
  const sent: unknown[] = [];
  const client = {
    beta: {
      messages: {
        parse: (params: unknown) => {
          sent.push(params);
          return answer();
        },
      },
    },
  } as unknown as Anthropic;
  return { client, sent };
}

const image = { buffer: Buffer.from([0xff, 0xd8, 0xff, 0x00]), mimeType: 'image/jpeg' };

describe('Analyse de la photo du colis par Claude', () => {
  it('envoie la photo avec les consignes, un effort bas, la sortie structurée et le repli', async () => {
    const { client, sent } = fakeClient(() =>
      Promise.resolve({ stop_reason: 'end_turn', parsed_output: verdict }),
    );
    const vision = new ClaudeParcelVision({ apiKey: 'k', model: 'claude-opus-5-5', client });
    expect(await vision.analyze(image)).toEqual(verdict);
    expect(vision.engine).toBe('claude:claude-opus-5-5');
    expect(sent[0]).toMatchObject({
      model: 'claude-opus-5-5',
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low', format: expect.any(Object) },
      system: PARCEL_SYSTEM_PROMPT,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: 'image/jpeg',
                data: image.buffer.toString('base64'),
              },
            },
            { type: 'text', text: expect.any(String) },
          ],
        },
      ],
    });
  });

  it('refus du modèle, réponse illisible ou erreur d’API : analyse indisponible', async () => {
    const answers: (() => Promise<unknown>)[] = [
      () => Promise.resolve({ stop_reason: 'refusal', parsed_output: null }),
      () => Promise.resolve({ stop_reason: 'max_tokens', parsed_output: null }),
      () =>
        Promise.reject(
          new Anthropic.APIError(529, { type: 'overloaded_error' }, 'Overloaded', new Headers()),
        ),
      () => Promise.reject(new TypeError('fetch failed')),
    ];
    for (const answer of answers) {
      const { client } = fakeClient(answer);
      const vision = new ClaudeParcelVision({ apiKey: 'k', model: 'claude-opus-5-5', client });
      await expect(vision.analyze(image)).rejects.toBeInstanceOf(ParcelVisionUnavailableError);
    }
  });
});
