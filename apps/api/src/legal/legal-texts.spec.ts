import { resolve } from 'node:path';
import { readLegalSources } from './legal-sources.js';
import { LEGAL_TEXTS } from './legal-texts.generated.js';
import { signupConsents, termsAccepted } from './legal-versions.js';

describe('Textes juridiques', () => {
  it('sont la copie exacte de docs/juridique (lancer `pnpm --filter @tara/api legal`)', () => {
    const repo = resolve(import.meta.dirname, '../../../..');
    expect(LEGAL_TEXTS).toEqual(readLegalSources(repo));
  });

  it('acceptent à l’inscription les conditions d’une seule app et la confidentialité', () => {
    const privacy = LEGAL_TEXTS.confidentialite.version;
    const client = LEGAL_TEXTS.expediteurs.version;
    expect(signupConsents({ expediteurs: client, confidentialite: privacy })).toEqual([
      { kind: 'TERMS', version: `expediteurs:${client}` },
      { kind: 'PRIVACY', version: `confidentialite:${privacy}` },
    ]);
    expect(signupConsents({ expediteurs: client })).toBeNull();
    expect(signupConsents({ confidentialite: privacy })).toBeNull();
    expect(signupConsents({ expediteurs: '2000-01', confidentialite: privacy })).toBeNull();
    expect(
      signupConsents({
        expediteurs: client,
        livreurs: LEGAL_TEXTS.livreurs.version,
        confidentialite: privacy,
      }),
    ).toBeNull();
  });

  it('exigent les conditions de l’app et la confidentialité en vigueur', () => {
    const privacy = `confidentialite:${LEGAL_TEXTS.confidentialite.version}`;
    const rider = `livreurs:${LEGAL_TEXTS.livreurs.version}`;
    expect(termsAccepted('rider', [rider, privacy])).toBe(true);
    expect(termsAccepted('rider', [privacy])).toBe(false);
    expect(termsAccepted('client', [rider, privacy])).toBe(false);
  });
});
