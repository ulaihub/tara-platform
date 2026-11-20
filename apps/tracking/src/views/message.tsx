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
  /** Dans la feuille sous la ville (maquette Web-Point) : pastille ronde, texte centré. */
  sheet?: boolean;
}> = ({ icon, title, body, action, tone = 'muted', sheet }) =>
  sheet ? (
    <section class={`done ${tone}`} role="status">
      <span class="orb" aria-hidden="true">
        <span class="fill" />
        <Icon name={icon} size={32} />
      </span>
      <h1>{title}</h1>
      <p>{body}</p>
    </section>
  ) : (
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
