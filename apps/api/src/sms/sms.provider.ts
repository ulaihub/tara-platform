import { Logger } from '@nestjs/common';

export const SMS_PROVIDER = Symbol('SMS_PROVIDER');

/** Résultat d'un envoi : `provider` indique le fournisseur réellement utilisé (secours). */
export interface SmsSendResult {
  providerReference: string;
  provider?: string;
}

/** Envoi de SMS (Orange Cameroun, Twilio, ou factice en développement). */
export interface SmsProvider {
  readonly name: string;
  send(to: string, text: string): Promise<SmsSendResult>;
}

export interface SentSms {
  to: string;
  text: string;
  at: Date;
}

/**
 * Fournisseur factice pour le développement et les tests : n'envoie rien, garde les
 * 2 000 derniers messages en mémoire et les écrit dans le journal. Interdit en production
 * (contrôlé au démarrage par la validation de la configuration).
 */
export class FakeSmsProvider implements SmsProvider {
  readonly name = 'fake';
  readonly outbox: SentSms[] = [];
  private readonly logger = new Logger('FakeSms');
  private counter = 0;

  send(to: string, text: string): Promise<SmsSendResult> {
    this.outbox.push({ to, text, at: new Date() });
    if (this.outbox.length > 2_000) this.outbox.shift();
    this.logger.log(`→ ${to} : ${text}`);
    this.counter += 1;
    return Promise.resolve({ providerReference: `fake-${this.counter}` });
  }

  /** Dernier message envoyé à un numéro (utilisé par les tests). */
  lastTo(to: string): SentSms | undefined {
    return this.outbox.filter((sms) => sms.to === to).at(-1);
  }
}
