import { redact } from './redacting-logger.js';

describe('masquage des journaux', () => {
  it.each([
    ['SMS → +237690123456 : bonjour', 'SMS → +2376•••••56 : bonjour'],
    ['appel au 237 6 90 12 34 56', 'appel au +2376•••••56'],
    ['+237-655-44-33-22 injoignable', '+2376•••••22 injoignable'],
  ])('masque les numéros camerounais : %s', (input, expected) => {
    expect(redact(input)).toBe(expected);
  });

  it('ne touche pas aux montants ni aux références', () => {
    expect(redact('Commande TR-7K3P9Q : 15000 FCFA, 6 colis')).toBe(
      'Commande TR-7K3P9Q : 15000 FCFA, 6 colis',
    );
  });

  it('masque les jetons de session', () => {
    expect(redact('Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl')).toBe(
      'Authorization: Bearer [jeton]',
    );
    expect(redact('jeton eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2ln')).toBe('jeton [jeton]');
  });

  it('masque les jetons des liens publics', () => {
    expect(redact('GET /v1/public/tracking/AbCdEfGhIjKlMnOpQrStUv')).toBe(
      'GET /v1/public/tracking/[jeton]',
    );
    expect(redact('Suivi : https://tara.cm/t/AbCdEfGhIjKlMnOpQrStUv')).toBe(
      'Suivi : https://tara.cm/t/[jeton]',
    );
  });
});
