/** Étapes de la connexion de l'équipe. */
export type LoginStep = 'phone' | 'code' | 'mfa-setup' | 'mfa-verify';

export interface LoginState {
  step: LoginStep;
  error?: string;
  /** Numéro affiché (« +237 6 77 12 34 56 »). */
  phone?: string;
  /** Prochain envoi possible du code SMS (ms). */
  resendAt?: number;
  /** Enrôlement : QR code (image SVG en data URI) et clé à saisir à la main. */
  qr?: string;
  secret?: string;
}
