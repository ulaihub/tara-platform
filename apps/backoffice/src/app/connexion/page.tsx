import type { Metadata } from 'next';
import { cookies } from 'next/headers';
import { City3D } from '@/components/city-3d';
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
    <main className="relative grid min-h-screen lg:grid-cols-[760px_1fr]">
      <div className="bo-blobs" aria-hidden="true">
        <i />
        <i />
      </div>
      <section className="relative hidden min-h-[640px] overflow-hidden lg:block">
        <City3D />
        <div className="absolute right-12 bottom-12 left-12 flex flex-col gap-2.5 text-white [text-shadow:0_2px_12px_rgba(0,0,0,.5)]">
          <span className="text-[13px] font-extrabold tracking-[.12em] text-[var(--accent-2)]">
            ESPACE ÉQUIPE
          </span>
          <h1 className="font-display text-[40px] leading-[1.1] font-bold">
            Douala en direct,
            <br />
            chaque course sous les yeux.
          </h1>
        </div>
      </section>
      <section className="relative z-[1] flex items-center justify-center p-6">
        <div className="bo-glass flex w-full max-w-[440px] flex-col gap-4 rounded-[22px] p-[34px]">
          <span className="flex self-start rounded-[14px] bg-[#16120E] px-2.5 py-2">
            <Logo dark className="h-9 w-[52px] object-contain" />
          </span>
          <LoginFlow initial={state} expired={expiree === '1'} />
          <p className="text-[11px] text-faint">
            Accès réservé à l’équipe Tara. Double authentification obligatoire ; chaque action est
            inscrite au journal.
          </p>
        </div>
      </section>
    </main>
  );
}
