import type { SmsProvider, SmsSendResult } from './sms.provider.js';

export interface TwilioSmsConfig {
  accountSid: string;
  authToken: string;
  /** Nom alphanumérique enregistré pour le Cameroun, ou numéro E.164. */
  from: string;
  fetch?: typeof fetch;
}

/** Twilio Programmable Messaging : fournisseur de secours, ouvert sans démarche locale. */
export class TwilioSmsProvider implements SmsProvider {
  readonly name = 'twilio';
  private readonly http: typeof fetch;

  constructor(private readonly config: TwilioSmsConfig) {
    this.http = config.fetch ?? fetch;
  }

  async send(to: string, text: string): Promise<SmsSendResult> {
    const basic = Buffer.from(`${this.config.accountSid}:${this.config.authToken}`).toString(
      'base64',
    );
    const response = await this.http(
      `https://api.twilio.com/2010-04-01/Accounts/${this.config.accountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${basic}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({ To: to, From: this.config.from, Body: text }),
        signal: AbortSignal.timeout(10_000),
      },
    );
    const body = (await response.json().catch(() => ({}))) as { sid?: string; code?: number };
    if (!response.ok || !body.sid) {
      throw new Error(
        `Envoi Twilio refusé (${response.status}${body.code ? ` ${body.code}` : ''})`,
      );
    }
    return { providerReference: body.sid, provider: this.name };
  }
}
