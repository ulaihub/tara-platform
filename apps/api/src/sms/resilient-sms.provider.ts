import { Logger } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { cameroonDate } from '../common/time.js';
import type { SmsProvider, SmsSendResult } from './sms.provider.js';

/**
 * Bascule automatique : si le fournisseur principal échoue (panne, solde épuisé, jeton
 * refusé), le message part par le secours. La connexion par SMS ne dépend ainsi d'aucun
 * fournisseur unique.
 */
export class FailoverSmsProvider implements SmsProvider {
  private readonly logger = new Logger('Sms');
  readonly name: string;

  constructor(private readonly providers: SmsProvider[]) {
    this.name = providers.map((provider) => provider.name).join('>');
  }

  async send(to: string, text: string): Promise<SmsSendResult> {
    let lastError: unknown = new Error('Aucun fournisseur SMS');
    for (const provider of this.providers) {
      try {
        const result = await provider.send(to, text);
        return { ...result, provider: result.provider ?? provider.name };
      } catch (error) {
        lastError = error;
        this.logger.warn(`SMS non envoyé par ${provider.name} : ${String(error)}`);
      }
    }
    throw lastError;
  }
}

export type SmsVolumeAlert = (level: 80 | 100, count: number, limit: number) => void;

/**
 * Compte les SMS envoyés dans la journée (heure du Cameroun), toutes instances confondues,
 * et alerte une seule fois à 80 % puis à 100 % du seuil : une hausse anormale (pompage,
 * boucle d'envoi) se voit avant la facture.
 */
export class MeteredSmsProvider implements SmsProvider {
  private readonly logger = new Logger('SmsVolume');
  readonly name: string;

  constructor(
    private readonly inner: SmsProvider,
    private readonly redis: Redis,
    private readonly dailyLimit: number,
    private readonly onAlert: SmsVolumeAlert = () => undefined,
  ) {
    this.name = inner.name;
  }

  async send(to: string, text: string): Promise<SmsSendResult> {
    const result = await this.inner.send(to, text);
    try {
      const key = `sms:count:${cameroonDate(new Date())}`;
      const count = await this.redis.incr(key);
      if (count === 1) await this.redis.expire(key, 3 * 86_400);
      for (const level of [80, 100] as const) {
        if (count === Math.ceil((this.dailyLimit * level) / 100)) {
          this.logger.error(
            `Volume de SMS : ${count} aujourd'hui (${level} % du seuil de ${this.dailyLimit})`,
          );
          this.onAlert(level, count, this.dailyLimit);
        }
      }
    } catch (error) {
      // Le comptage ne doit jamais empêcher un envoi.
      this.logger.warn(`Comptage des SMS indisponible : ${String(error)}`);
    }
    return result;
  }
}
