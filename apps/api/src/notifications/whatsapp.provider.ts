import { Logger } from '@nestjs/common';
import type { AppLocale } from '../common/i18n/locale.js';

export const WHATSAPP_PROVIDER = Symbol('WHATSAPP_PROVIDER');

/**
 * Message WhatsApp à l'initiative de Tara : l'API Cloud de Meta n'accepte hors conversation
 * ouverte que des modèles approuvés à l'avance. Chaque modèle Tara a son équivalent chez
 * Meta, nommé `tara_<modèle>` (ex. tara_delivery_code), avec les paramètres dans l'ordre.
 */
export interface WhatsAppMessage {
  template: string;
  locale: AppLocale;
  parameters: string[];
}

export interface WhatsAppProvider {
  readonly name: string;
  send(to: string, message: WhatsAppMessage): Promise<{ providerReference: string }>;
}

/** Fournisseur factice : garde les messages ; certains numéros échouent (tests du repli). */
export class FakeWhatsAppProvider implements WhatsAppProvider {
  readonly name = 'fake-whatsapp';
  readonly outbox: { to: string; message: WhatsAppMessage; reference: string }[] = [];
  /** Numéros sans WhatsApp : l'envoi échoue immédiatement. */
  readonly failingNumbers = new Set<string>();
  private readonly logger = new Logger('FakeWhatsApp');
  private counter = 0;

  send(to: string, message: WhatsAppMessage): Promise<{ providerReference: string }> {
    if (this.failingNumbers.has(to)) {
      return Promise.reject(new Error('Numéro sans compte WhatsApp'));
    }
    this.counter += 1;
    const reference = `wamid.fake-${this.counter}`;
    this.outbox.push({ to, message, reference });
    if (this.outbox.length > 200) this.outbox.shift();
    this.logger.log(`→ ${to} : ${message.template}`);
    return Promise.resolve({ providerReference: reference });
  }

  lastTo(to: string): WhatsAppMessage | undefined {
    return this.outbox.filter((entry) => entry.to === to).at(-1)?.message;
  }
}

/** WhatsApp Cloud API (Meta). Les accusés de remise arrivent par le webhook. */
export class MetaWhatsAppProvider implements WhatsAppProvider {
  readonly name = 'whatsapp-meta';

  constructor(
    private readonly phoneNumberId: string,
    private readonly accessToken: string,
    private readonly apiVersion: string,
  ) {}

  async send(to: string, message: WhatsAppMessage): Promise<{ providerReference: string }> {
    const response = await fetch(
      `https://graph.facebook.com/${this.apiVersion}/${encodeURIComponent(this.phoneNumberId)}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: to.replace(/^\+/, ''),
          type: 'template',
          template: {
            name: message.template,
            language: { code: message.locale },
            components: [
              {
                type: 'body',
                parameters: message.parameters.map((text) => ({ type: 'text', text })),
              },
            ],
          },
        }),
        signal: AbortSignal.timeout(10_000),
      },
    );
    if (!response.ok) {
      throw new Error(
        `Envoi WhatsApp refusé (${response.status}) : ${(await response.text()).slice(0, 200)}`,
      );
    }
    const body = (await response.json()) as { messages?: { id: string }[] };
    const id = body.messages?.[0]?.id;
    if (!id) throw new Error('Réponse WhatsApp sans identifiant de message');
    return { providerReference: id };
  }
}
