import { codFee, merchantPayable, naturalBalance, PLATFORM_ACCOUNTS } from './ledger.accounts.js';
import { normalizePostings, UnbalancedEntryError } from './ledger.service.js';

describe('grand livre', () => {
  const merchant = merchantPayable('m1');

  it('regroupe les lignes par compte et ignore les lignes nulles', () => {
    const lines = normalizePostings([
      { account: PLATFORM_ACCOUNTS.mobileMoney, amount: 10_000 },
      { account: merchant, amount: -9_750 },
      { account: PLATFORM_ACCOUNTS.codFees, amount: -250 },
      { account: PLATFORM_ACCOUNTS.promotions, amount: 0 },
    ]);
    expect(lines.map((line) => [line.account.code, line.amount])).toEqual([
      ['platform:mobile_money', 10_000],
      ['merchant:m1:payable', -9_750],
      ['platform:revenue:cod_fees', -250],
    ]);
  });

  it('refuse une écriture déséquilibrée, à une ligne ou à montant non entier', () => {
    expect(() =>
      normalizePostings([
        { account: PLATFORM_ACCOUNTS.mobileMoney, amount: 100 },
        { account: merchant, amount: -99 },
      ]),
    ).toThrow(UnbalancedEntryError);
    expect(() =>
      normalizePostings([
        { account: merchant, amount: 100 },
        { account: merchant, amount: -100 },
      ]),
    ).toThrow(/deux lignes/);
    expect(() =>
      normalizePostings([
        { account: PLATFORM_ACCOUNTS.mobileMoney, amount: 0.5 },
        { account: merchant, amount: -0.5 },
      ]),
    ).toThrow(/entier/);
  });

  it('donne le solde dans le sens naturel du compte', () => {
    expect(naturalBalance('ASSET', 5_000)).toBe(5_000);
    expect(naturalBalance('LIABILITY', -5_000)).toBe(5_000);
    expect(naturalBalance('REVENUE', -300)).toBe(300);
  });

  it('calcule les frais d’encaissement : 2 %, minimum 250 FCFA, plafonnés au montant', () => {
    expect(codFee(0)).toBe(0);
    expect(codFee(200)).toBe(200);
    expect(codFee(5_000)).toBe(250);
    expect(codFee(50_000)).toBe(1_000);
    expect(codFee(12_345)).toBe(250);
    expect(codFee(30_025)).toBe(601);
  });
});
