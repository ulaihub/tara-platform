import { randomUUID } from 'node:crypto';
import { Logger } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { maskPhone } from '../common/phone.js';
import type { SmsProvider, SmsSendResult } from './sms.provider.js';

/** Liste Redis des messages gardés (clé réelle préfixée par `tara:`), lue par `tara sms`. */
export const TEST_OUTBOX_KEY = 'sms:test-outbox';
const OUTBOX_SIZE = 200;
const OUTBOX_TTL_SECONDS = 86_400;

const timeFormat = new Intl.DateTimeFormat('fr-FR', {
  timeZone: 'Africa/Douala',
  day: '2-digit',
  month: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
});

/**
 * Téléphones de test : leurs SMS ne partent pas chez l'opérateur. Le message est gardé
 * 24 h dans Redis, sur le réseau interne du serveur, et seul root le lit (`tara sms`).
 * Permet de tester les apps sur de vrais téléphones sans crédit SMS, comme les numéros de
 * test de Firebase. Les autres numéros passent par le fournisseur réel.
 */
export class TestNumbersSmsProvider implements SmsProvider {
  private readonly logger = new Logger('Sms');
  readonly name: string;

  constructor(
    private readonly inner: SmsProvider,
    private readonly testNumbers: ReadonlySet<string>,
    private readonly redis: Redis,
  ) {
    this.name = inner.name;
    if (testNumbers.size > 0) {
      this.logger.warn(
        `${testNumbers.size} téléphone(s) de test : leurs SMS restent sur le serveur (tara sms)`,
      );
    }
  }

  async send(to: string, text: string): Promise<SmsSendResult> {
    if (!this.testNumbers.has(to)) return this.inner.send(to, text);
    const at = timeFormat.format(new Date());
    const results = await this.redis
      .multi()
      .lpush(TEST_OUTBOX_KEY, `${at}  ${to}  ${text}`)
      .ltrim(TEST_OUTBOX_KEY, 0, OUTBOX_SIZE - 1)
      .expire(TEST_OUTBOX_KEY, OUTBOX_TTL_SECONDS)
      .exec();
    if (!results || results.some(([error]) => error)) {
      throw new Error('SMS de test non gardé (Redis indisponible)');
    }
    this.logger.log(`SMS de test gardé pour ${maskPhone(to)}`);
    return { providerReference: `test-${randomUUID()}`, provider: 'test' };
  }
}
