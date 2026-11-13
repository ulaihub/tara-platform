'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import QRCode from 'qrcode';
import { ApiError, api } from '@/lib/api';
import { config } from '@/lib/config';
import { cameroonMobile, displayPhone } from '@/lib/phone';
import type { Tokens } from '@/lib/refresh';
import {
  DEVICE_COOKIE,
  LOGIN_COOKIE,
  LOGIN_MAX_AGE,
  SESSION_COOKIE,
  SESSION_MAX_AGE,
  type Session,
  cookieOptions,
  openLogin,
  openSession,
  sealLogin,
  sealSession,
  staffRoles,
} from '@/lib/session';
import type { LoginState } from './state';

interface Challenge {
  challengeId: string;
  resendAfterSeconds: number;
}

interface AuthSession extends Tokens {
  user: { id: string; phone: string; fullName: string | null; roles: string[] };
}

interface Me {
  roles: string[];
  fullName: string | null;
  staff: { mfaEnrolled: boolean; mfaVerified: boolean } | null;
}

/** Champ texte du formulaire (un fichier envoyé à la place compte pour vide). */
function field(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value : '';
}

const message = (error: unknown) =>
  error instanceof ApiError ? error.message : 'Une erreur est survenue. Réessayez.';

/** Appareil de ce navigateur (sessions et journal d'audit de l'API). */
async function deviceId(): Promise<string> {
  const store = await cookies();
  const existing = store.get(DEVICE_COOKIE)?.value;
  if (existing && /^[0-9a-f-]{36}$/.test(existing)) return existing;
  const id = crypto.randomUUID();
  store.set(DEVICE_COOKIE, id, cookieOptions(5 * 365 * 24 * 3600, config.secureCookies));
  return id;
}

async function saveSession(session: Session) {
  const store = await cookies();
  store.set(
    SESSION_COOKIE,
    sealSession(session, config.sessionSecret),
    cookieOptions(SESSION_MAX_AGE, config.secureCookies),
  );
}

/** 1 · Numéro : le code part par SMS. */
export async function requestCode(_: LoginState, form: FormData): Promise<LoginState> {
  const phone = cameroonMobile(field(form, 'phone'));
  if (!phone)
    return { step: 'phone', error: 'Numéro de mobile camerounais à 9 chiffres, commençant par 6.' };
  try {
    await deviceId();
    const challenge = await api<Challenge>('/auth/otp', {
      method: 'POST',
      body: { phone, locale: 'fr' },
    });
    const resendAt = Date.now() + challenge.resendAfterSeconds * 1000;
    const store = await cookies();
    store.set(
      LOGIN_COOKIE,
      sealLogin({ phone, challengeId: challenge.challengeId, resendAt }, config.sessionSecret),
      cookieOptions(LOGIN_MAX_AGE, config.secureCookies),
    );
    return { step: 'code', phone: displayPhone(phone), resendAt };
  } catch (error) {
    return { step: 'phone', error: message(error) };
  }
}

/** 2 · Code SMS : session ouverte, réservée aux rôles de l'équipe. */
export async function verifyCode(_: LoginState, form: FormData): Promise<LoginState> {
  const store = await cookies();
  const login = openLogin(store.get(LOGIN_COOKIE)?.value, config.sessionSecret);
  if (!login) return { step: 'phone', error: 'Le code a expiré : redemandez-en un.' };
  const back: LoginState = {
    step: 'code',
    phone: displayPhone(login.phone),
    resendAt: login.resendAt,
  };
  const code = field(form, 'code').replace(/\D/g, '');
  if (code.length !== 6) return { ...back, error: 'Le code fait 6 chiffres.' };
  let auth: AuthSession;
  try {
    auth = await api<AuthSession>('/auth/otp/verify', {
      method: 'POST',
      body: {
        challengeId: login.challengeId,
        code,
        locale: 'fr',
        device: { installationId: await deviceId(), platform: 'WEB', appVersion: 'back-office' },
      },
    });
  } catch (error) {
    if (error instanceof ApiError && error.code === 'TERMS_REQUIRED') {
      return { step: 'phone', error: 'Ce numéro n’a pas de compte dans l’équipe Tara.' };
    }
    return { ...back, error: message(error) };
  }
  store.delete(LOGIN_COOKIE);
  if (staffRoles(auth.user.roles).length === 0) {
    await api('/auth/logout', { method: 'POST', body: { refreshToken: auth.refreshToken } }).catch(
      () => null,
    );
    return { step: 'phone', error: 'Accès réservé à l’équipe Tara.' };
  }
  const me = await api<Me>('/me', { token: auth.accessToken });
  await saveSession({
    accessToken: auth.accessToken,
    refreshToken: auth.refreshToken,
    accessExpiresAt: Date.now() + auth.expiresIn * 1000,
    userId: auth.user.id,
    phone: auth.user.phone,
    name: me.fullName,
    roles: me.roles,
    mfaVerified: false,
  });
  return me.staff?.mfaEnrolled ? { step: 'mfa-verify' } : { step: 'mfa-setup' };
}

async function pendingSession(): Promise<Session | null> {
  const store = await cookies();
  return openSession(store.get(SESSION_COOKIE)?.value, config.sessionSecret);
}

/** 3a · Premier passage : QR code à scanner dans l'application d'authentification. */
export async function startSetup(): Promise<LoginState> {
  const session = await pendingSession();
  if (!session) return { step: 'phone', error: 'Session expirée : reconnectez-vous.' };
  try {
    const setup = await api<{ secret: string; otpauthUrl: string }>('/auth/mfa/setup', {
      method: 'POST',
      token: session.accessToken,
    });
    const svg = await QRCode.toString(setup.otpauthUrl, { type: 'svg', margin: 1, width: 220 });
    return {
      step: 'mfa-setup',
      qr: `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`,
      secret: setup.secret,
    };
  } catch (error) {
    if (error instanceof ApiError && error.code === 'MFA_ALREADY_ENABLED')
      return { step: 'mfa-verify' };
    return { step: 'mfa-setup', error: message(error) };
  }
}

/** 3b · Code de l'application d'authentification : accès au back-office. */
export async function confirmMfa(previous: LoginState, form: FormData): Promise<LoginState> {
  const session = await pendingSession();
  if (!session) return { step: 'phone', error: 'Session expirée : reconnectez-vous.' };
  const code = field(form, 'code').replace(/\D/g, '');
  if (code.length !== 6) return { ...previous, error: 'Le code fait 6 chiffres.' };
  const path = previous.step === 'mfa-setup' ? '/auth/mfa/activate' : '/auth/mfa/verify';
  let tokens: Tokens;
  try {
    tokens = await api<Tokens>(path, {
      method: 'POST',
      token: session.accessToken,
      body: { code, refreshToken: session.refreshToken },
    });
  } catch (error) {
    return { ...previous, error: message(error) };
  }
  await saveSession({
    ...session,
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    accessExpiresAt: Date.now() + tokens.expiresIn * 1000,
    mfaVerified: true,
  });
  redirect('/');
}

/** Une seule action pour le formulaire : l'étape demandée est dans `intent`. */
export async function loginStep(previous: LoginState, form: FormData): Promise<LoginState> {
  switch (form.get('intent')) {
    case 'request':
      return requestCode(previous, form);
    case 'verify':
      return verifyCode(previous, form);
    case 'setup':
      return startSetup();
    case 'confirm':
      return confirmMfa(previous, form);
    case 'restart':
      return restart();
    default:
      return previous;
  }
}

/** Retour au numéro (autre numéro, code jamais reçu). */
export async function restart(): Promise<LoginState> {
  const store = await cookies();
  store.delete(LOGIN_COOKIE);
  const session = openSession(store.get(SESSION_COOKIE)?.value, config.sessionSecret);
  if (session && !session.mfaVerified) {
    await api('/auth/logout', {
      method: 'POST',
      body: { refreshToken: session.refreshToken },
    }).catch(() => null);
    store.delete(SESSION_COOKIE);
  }
  return { step: 'phone' };
}

/** Déconnexion : session fermée côté API, cookie effacé. */
export async function logout(): Promise<void> {
  const store = await cookies();
  const session = openSession(store.get(SESSION_COOKIE)?.value, config.sessionSecret);
  if (session) {
    await api('/auth/logout', {
      method: 'POST',
      body: { refreshToken: session.refreshToken },
    }).catch(() => null);
  }
  store.delete(SESSION_COOKIE);
  redirect('/connexion');
}
