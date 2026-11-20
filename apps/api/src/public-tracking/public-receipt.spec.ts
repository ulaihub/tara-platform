import { describe, expect, it } from 'vitest';
import type { Env } from '../config/env.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { PublicReceiptService } from './public-receipt.service.js';
import { readReceiptCode, receiptCode, receiptUrl } from './receipt-code.js';

const SECRET = 'un-secret-de-test-suffisamment-long-pour-hmac';

describe('code signé du reçu', () => {
  it('se relit avec le bon secret, en majuscules ou minuscules', () => {
    const code = receiptCode(SECRET, 'TR-48301K');
    expect(code).toMatch(/^TR-48301K-[0-9A-HJKMNP-TV-Z]{8}$/);
    expect(readReceiptCode(SECRET, code)).toBe('TR-48301K');
    expect(readReceiptCode(SECRET, ` ${code.toLowerCase()} `)).toBe('TR-48301K');
  });

  it('refuse une signature fausse, une autre référence ou un autre secret', () => {
    const code = receiptCode(SECRET, 'TR-48301K');
    const last = code.at(-1) === 'A' ? 'B' : 'A';
    expect(readReceiptCode(SECRET, code.slice(0, -1) + last)).toBeNull();
    expect(readReceiptCode(SECRET, code.replace('TR-48301K', 'TR-48302K'))).toBeNull();
    expect(readReceiptCode(`${SECRET}-autre`, code)).toBeNull();
    expect(readReceiptCode(SECRET, 'TR-48301K')).toBeNull();
    expect(readReceiptCode(SECRET, '../etc/passwd')).toBeNull();
  });

  it('donne le lien du QR sur le site public', () => {
    expect(receiptUrl('https://tara.cm/', SECRET, 'TR-48301K')).toBe(
      `https://tara.cm/r/${receiptCode(SECRET, 'TR-48301K')}`,
    );
  });
});

describe('vérification publique du reçu', () => {
  const order = {
    reference: 'TR-48301K',
    status: 'DELIVERED',
    createdAt: new Date('2026-11-19T13:32:00Z'),
    recipientName: 'Marie Ngo',
    totalPrice: 1200,
    feePaidAt: new Date('2026-11-19T13:32:00Z'),
    deliveredAt: new Date('2026-11-19T14:24:00Z'),
    merchant: { shopName: 'Awa Fashion' },
    sender: { fullName: 'Awa Ngono' },
    dropoffAddress: { neighborhood: { name: 'Bonapriso' } },
    codCollection: { collectedAmount: 15000 },
  };
  const lookups: string[] = [];
  const prisma = {
    order: {
      findUnique: ({ where }: { where: { reference: string } }) => {
        lookups.push(where.reference);
        return Promise.resolve(where.reference === order.reference ? order : null);
      },
    },
  } as unknown as PrismaService;
  const service = new PublicReceiptService(prisma, { CODE_HASH_SECRET: SECRET } as Env);

  it('montre ce qui est imprimé, sans numéro de téléphone', async () => {
    const receipt = await service.verify(receiptCode(SECRET, 'TR-48301K'));
    expect(receipt).toEqual({
      reference: 'TR-48301K',
      status: 'DELIVERED',
      issuedAt: '2026-11-19T13:32:00.000Z',
      senderName: 'Awa Fashion',
      recipientName: 'Marie N.',
      dropoffNeighborhood: 'Bonapriso',
      fee: 1200,
      feePaid: true,
      deliveredAt: '2026-11-19T14:24:00.000Z',
      collectedForSender: 15000,
    });
  });

  it('code faux ou reçu inconnu : même réponse, et la base n’est pas lue sans signature', async () => {
    lookups.length = 0;
    await expect(service.verify('TR-48301K-AAAAAAAA')).rejects.toMatchObject({ status: 404 });
    expect(lookups).toEqual([]);
    await expect(service.verify(receiptCode(SECRET, 'TR-00000A'))).rejects.toMatchObject({
      status: 404,
    });
  });
});
