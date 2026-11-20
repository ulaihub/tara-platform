import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from 'react';
import { Icon, type IconName } from './icon';

/** Classes Tailwind combinées, valeurs vides ignorées. */
export function cx(...classes: (string | false | null | undefined)[]): string {
  return classes.filter(Boolean).join(' ');
}

/** Bouton de la marque (dégradé orange) ou secondaire (verre clair). */
export function Button({
  variant = 'primary',
  icon,
  loading = false,
  className,
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'ghost' | 'danger';
  icon?: IconName;
  loading?: boolean;
}) {
  return (
    <button
      {...props}
      disabled={props.disabled || loading}
      aria-busy={loading || undefined}
      className={cx(
        'inline-flex min-h-12 items-center justify-center gap-2 rounded-2xl px-5 text-[15px] font-extrabold transition',
        'disabled:cursor-not-allowed disabled:opacity-50',
        variant === 'primary' && 'bg-brand text-on-brand shadow-card hover:brightness-105',
        variant === 'ghost' && 'border border-line bg-panel text-text hover:bg-panel-soft',
        variant === 'danger' &&
          'border border-danger/30 bg-danger-bg text-danger hover:brightness-110',
        className,
      )}
    >
      {loading ? <Spinner /> : icon ? <Icon name={icon} size={18} /> : null}
      {children}
    </button>
  );
}

export function Spinner() {
  return (
    <span
      aria-hidden="true"
      className="inline-block size-4 animate-spin rounded-full border-2 border-current border-t-transparent"
    />
  );
}

/** Carte blanche aux bords arrondis, comme dans les apps. */
export function Card({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <section className={cx('bo-glass rounded-[22px] p-6 shadow-card', className)}>
      {children}
    </section>
  );
}

/** Champ avec son libellé, au-dessus. */
export function Field({
  label,
  hint,
  className,
  inputClassName,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  hint?: string;
  inputClassName?: string;
}) {
  return (
    <label className={cx('block', className)}>
      <span className="mb-1.5 block text-[13px] font-bold text-muted">{label}</span>
      <input
        {...props}
        className={cx(
          'block min-h-12 w-full rounded-2xl border border-line bg-panel-soft px-4 text-[16px] text-text placeholder:text-faint focus:border-accent-line focus:outline-none',
          inputClassName,
        )}
      />
      {hint ? <span className="mt-1.5 block text-[13px] text-faint">{hint}</span> : null}
    </label>
  );
}

/** Message d'erreur annoncé par les lecteurs d'écran. */
export function ErrorLine({ children }: { children: ReactNode }) {
  return (
    <p role="alert" className="flex items-start gap-2 text-[14px] font-bold text-danger">
      <Icon name="alertCircle" size={18} className="mt-0.5 shrink-0" />
      <span>{children}</span>
    </p>
  );
}

export function Note({
  tone = 'accent',
  children,
}: {
  tone?: 'accent' | 'ok' | 'warn';
  children: ReactNode;
}) {
  return (
    <p
      className={cx(
        'rounded-2xl px-4 py-3 text-[14px]',
        tone === 'accent' && 'border border-accent-line bg-accent-bg text-text',
        tone === 'ok' && 'bg-ok-bg font-bold text-ok',
        tone === 'warn' && 'bg-warn-bg text-text',
      )}
    >
      {children}
    </p>
  );
}

/** Pastille d'état (livreur libre, en course…). */
export function Badge({
  tone = 'neutral',
  children,
}: {
  tone?: 'neutral' | 'accent' | 'ok' | 'danger' | 'warn';
  children: ReactNode;
}) {
  return (
    <span
      className={cx(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[12px] font-extrabold',
        tone === 'neutral' && 'bg-track text-muted',
        tone === 'accent' && 'bg-accent-bg text-accent',
        tone === 'ok' && 'bg-ok-bg text-ok',
        tone === 'danger' && 'bg-danger-bg text-danger',
        tone === 'warn' && 'bg-warn-bg text-warn',
      )}
    >
      {children}
    </span>
  );
}

/**
 * Logo complet : version claire ou sombre selon le thème. La hauteur passe par une classe
 * (la politique de sécurité du site refuse les styles écrits dans la page).
 */
export function Logo({ className = 'h-11', dark = false }: { className?: string; dark?: boolean }) {
  const alt = 'Tara, livraison à la demande';
  if (dark) return <img src="/logo-sombre.svg" alt={alt} className={cx('w-auto', className)} />;
  return (
    <picture>
      <source srcSet="/logo-sombre.svg" media="(prefers-color-scheme: dark)" />
      <img src="/logo-clair.svg" alt={alt} className={cx('w-auto', className)} />
    </picture>
  );
}
