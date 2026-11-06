import type { Metadata } from 'next';
import { cookies } from 'next/headers';
import { Logo } from '@/components/ui';
import { api } from '@/lib/api';
import { config } from '@/lib/config';
import { displayPhone } from '@/lib/phone';
import { LOGIN_COOKIE, SESSION_COOKIE, openLogin, openSession } from '@/lib/session';
import { LoginFlow } from './login-flow';
import type { LoginState } from './state';

export const metadata: Metadata = { title: 'Connexion' };

/** Où reprendre la connexion : code envoyé, second facteur à donner, ou numéro. */
async function initialState(): Promise<LoginState> {
  const store = await cookies();
  const session = openSession(store.get(SESSION_COOKIE)?.value, config.sessionSecret);
  if (session && !session.mfaVerified) {
    const me = await api<{ staff: { mfaEnrolled: boolean } | null }>('/me', {
      token: session.accessToken,
    }).catch(() => null);
    if (me) return { step: me.staff?.mfaEnrolled ? 'mfa-verify' : 'mfa-setup' };
  }
  const login = openLogin(store.get(LOGIN_COOKIE)?.value, config.sessionSecret);
  if (login) return { step: 'code', phone: displayPhone(login.phone), resendAt: login.resendAt };
  return { step: 'phone' };
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ expiree?: string }>;
}) {
  const { expiree } = await searchParams;
  const state = await initialState();
  return (
    <main className="grid min-h-screen lg:grid-cols-[1.05fr_1fr]">
      <section className="relative hidden overflow-hidden bg-[#140800] p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <div
          aria-hidden="true"
          className="absolute -top-40 -right-32 size-[520px] rounded-full bg-brand opacity-60 blur-3xl"
        />
        <div
          aria-hidden="true"
          className="absolute -bottom-48 -left-40 size-[440px] rounded-full bg-[#ff3d00] opacity-30 blur-3xl"
        />
        <div className="relative">
          <Logo dark className="h-[52px]" />
        </div>
        <div className="relative max-w-md">
          <h1 className="font-display text-[40px] leading-tight font-extrabold tracking-tight">
            Le poste de pilotage de l’équipe Tara
          </h1>
          <p className="mt-4 text-[17px] text-white/75">
            Carte en direct, commandes, livreurs, support et finance : tout Douala au même endroit.
          </p>
        </div>
        <p className="relative text-[13px] text-white/50">
          Accès réservé à l’équipe · double authentification obligatoire
        </p>
      </section>
      <section className="flex items-center justify-center p-6">
        <div className="w-full max-w-[420px]">
          <div className="mb-10 lg:hidden">
            <Logo />
          </div>
          <LoginFlow initial={state} expired={expiree === '1'} />
        </div>
      </section>
    </main>
  );
}
