'use client';

import { useActionState, useEffect, useState } from 'react';
import { Button, ErrorLine, Field, Note } from '@/components/ui';
import { loginStep } from './actions';
import type { LoginState } from './state';

function Heading({ title, body }: { title: string; body: string }) {
  return (
    <div className="mb-6">
      <h2 className="font-display text-[28px] leading-tight font-bold tracking-tight">{title}</h2>
      <p className="mt-2 text-muted">{body}</p>
    </div>
  );
}

function Intent({ value }: { value: string }) {
  return <input type="hidden" name="intent" value={value} />;
}

/** Secondes avant de pouvoir redemander un code. */
function useCountdown(until: number | undefined): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!until) return;
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [until]);
  return until ? Math.max(0, Math.ceil((until - now) / 1000)) : 0;
}

const codeProps = {
  name: 'code',
  inputMode: 'numeric' as const,
  pattern: '[0-9]{6}',
  maxLength: 6,
  required: true,
  autoFocus: true,
  inputClassName: 'tracking-[0.4em]',
};

/**
 * Connexion de l'équipe : numéro, code SMS, puis second facteur (QR code à scanner la
 * première fois, code à 6 chiffres de l'application d'authentification ensuite).
 */
export function LoginFlow({ initial, expired }: { initial: LoginState; expired: boolean }) {
  const [state, action, pending] = useActionState(loginStep, initial);
  const wait = useCountdown(state.step === 'code' ? state.resendAt : undefined);

  if (state.step === 'phone') {
    return (
      <form action={action} className="space-y-5">
        <Heading
          title="Connexion de l’équipe"
          body="Votre numéro de mobile : un code vous est envoyé par SMS."
        />
        {expired ? <Note tone="warn">Votre session a pris fin : reconnectez-vous.</Note> : null}
        <Intent value="request" />
        <Field
          label="Numéro de téléphone"
          name="phone"
          type="tel"
          inputMode="tel"
          autoComplete="tel-national"
          placeholder="6XX XX XX XX"
          required
          autoFocus
        />
        {state.error ? <ErrorLine>{state.error}</ErrorLine> : null}
        <Button type="submit" className="w-full" icon="arrowRight" loading={pending}>
          Recevoir le code
        </Button>
      </form>
    );
  }

  if (state.step === 'code') {
    return (
      <div className="space-y-5">
        <form action={action} className="space-y-5">
          <Heading title="Code reçu par SMS" body={`Envoyé au ${state.phone ?? 'numéro saisi'}.`} />
          <Intent value="verify" />
          <Field label="Code à 6 chiffres" autoComplete="one-time-code" {...codeProps} />
          {state.error ? <ErrorLine>{state.error}</ErrorLine> : null}
          <Button type="submit" className="w-full" loading={pending}>
            Valider
          </Button>
        </form>
        <form action={action} className="flex items-center justify-between text-[14px]">
          <Intent value="restart" />
          <span className="text-faint">
            {wait > 0 ? `Nouveau code possible dans ${wait} s` : 'Pas reçu ?'}
          </span>
          <button
            type="submit"
            disabled={pending}
            className="font-bold text-accent hover:underline"
          >
            Changer de numéro
          </button>
        </form>
      </div>
    );
  }

  if (state.step === 'mfa-setup' && !state.qr) {
    return (
      <form action={action} className="space-y-5">
        <Heading
          title="Double authentification"
          body="Première connexion : installez une application d’authentification (Google Authenticator, Microsoft Authenticator ou Aegis), puis affichez le QR code à scanner."
        />
        <Intent value="setup" />
        {state.error ? <ErrorLine>{state.error}</ErrorLine> : null}
        <Button type="submit" className="w-full" icon="shieldCheck" loading={pending}>
          Afficher le QR code
        </Button>
      </form>
    );
  }

  return (
    <form action={action} className="space-y-5">
      {state.step === 'mfa-setup' ? (
        <>
          <Heading
            title="Scannez ce QR code"
            body="Dans l’application d’authentification, ajoutez un compte en scannant le code, puis saisissez les 6 chiffres affichés."
          />
          <div className="flex items-center gap-5 rounded-3xl border border-line bg-white p-4">
            <img
              src={state.qr}
              alt="QR code à scanner dans l’application d’authentification"
              width={150}
              height={150}
            />
            <p className="text-[13px] text-[#16120e]/70">
              Pas d’appareil photo ? Saisissez cette clé à la main :<br />
              <span className="mt-1 block font-mono text-[14px] font-bold text-[#16120e]">
                {state.secret?.match(/.{1,4}/g)?.join(' ')}
              </span>
            </p>
          </div>
        </>
      ) : (
        <Heading
          title="Code de sécurité"
          body="Ouvrez votre application d’authentification et saisissez le code à 6 chiffres de Tara."
        />
      )}
      <Intent value="confirm" />
      <Field label="Code à 6 chiffres" autoComplete="one-time-code" {...codeProps} />
      {state.error ? <ErrorLine>{state.error}</ErrorLine> : null}
      <Button type="submit" className="w-full" loading={pending}>
        Accéder au back-office
      </Button>
    </form>
  );
}
