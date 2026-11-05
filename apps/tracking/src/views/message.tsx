import type { FC } from 'hono/jsx';
import { Icon, type IconName } from './icons.js';

/** Page d'un seul message : lien introuvable, API injoignable, accueil. */
export const Message: FC<{
  icon: IconName;
  title: string;
  body: string;
  action?: { href: string; label: string };
  /** Pastille verte : action réussie (point envoyé). */
  tone?: 'ok' | 'muted';
}> = ({ icon, title, body, action, tone = 'muted' }) => (
  <section class="card">
    <div class="hero">
      <span class={`badge ${tone}`}>
        <Icon name={icon} size={24} />
      </span>
      <div class="grow">
        <h1>{title}</h1>
        <p class="sub">{body}</p>
      </div>
    </div>
    {action ? (
      <p>
        <a class="btn primary block" href={action.href}>
          {action.label}
        </a>
      </p>
    ) : null}
  </section>
);
