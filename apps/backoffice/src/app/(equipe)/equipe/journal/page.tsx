import type { Metadata } from 'next';
import Link from 'next/link';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime } from '@/lib/format';
import { displayPhone } from '@/lib/phone';
import type { AuditPage } from '@/lib/schemas';
import { actionLabel, entityLabel, preview, TEAM_ROLES } from '@/lib/team';
import { TeamHeader } from '../tabs';

export const metadata: Metadata = { title: 'Journal des actions' };

type Search = { type?: string; suite?: string };

function hrefWith(current: Search, changes: Partial<Search>): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries({ ...current, ...changes })) {
    if (value) params.set(key, value);
  }
  const query = params.toString();
  return query ? `/equipe/journal?${query}` : '/equipe/journal';
}

/**
 * Journal des actions sensibles (H8) : qui a fait quoi, quand, sur quoi, avec l'avant et
 * l'après. On ne peut ni le modifier ni l'effacer (garanti par la base de données).
 */
export default async function AuditPage({ searchParams }: { searchParams: Promise<Search> }) {
  await requireStaff(TEAM_ROLES);
  const search = await searchParams;
  const type = search.type && /^[a-z_]{2,40}$/.test(search.type) ? search.type : undefined;
  const page = await staffApi<AuditPage>('/admin/audit-log', {
    query: { entityType: type, cursor: search.suite, limit: 50 },
  });
  const current: Search = { type };

  return (
    <div className="mx-auto max-w-[1280px]">
      <TeamHeader
        current="/equipe/journal"
        aside="Qui a fait quoi, et quand. Le journal ne peut être ni modifié ni effacé."
      />
      <nav aria-label="Type d’action" className="mb-3 flex flex-wrap gap-2">
        {[undefined, ...page.entityTypes].map((value) => (
          <Link
            key={value ?? 'tout'}
            href={hrefWith(current, { type: value, suite: undefined })}
            aria-current={value === type ? 'page' : undefined}
            className={
              value === type
                ? 'min-h-9 rounded-xl bg-text px-3 py-2 text-[13px] font-bold text-bg'
                : 'min-h-9 rounded-xl bg-panel px-3 py-2 text-[13px] font-bold text-muted hover:text-text'
            }
          >
            {value ? entityLabel(value) : 'Tout'}
          </Link>
        ))}
      </nav>
      {page.items.length === 0 ? (
        <div className="rounded-3xl border border-line bg-panel px-6 py-16 text-center">
          <p className="font-display text-[18px] font-bold">Rien dans le journal</p>
        </div>
      ) : (
        <ul className="divide-y divide-line overflow-hidden rounded-3xl border border-line bg-panel shadow-card">
          {page.items.map((entry) => (
            <li key={entry.id} className="px-5 py-3">
              <details>
                <summary className="flex cursor-pointer flex-wrap items-baseline gap-x-3 gap-y-1">
                  <span className="w-[130px] shrink-0 text-[13px] text-muted tabular-nums">
                    {dateTime(entry.at)}
                  </span>
                  <span className="min-w-[220px] flex-1 text-[14px] font-bold">
                    {actionLabel(entry.action)}
                  </span>
                  <span className="text-[13px] text-muted">
                    {entry.actor
                      ? (entry.actor.name ??
                        (entry.actor.phone ? displayPhone(entry.actor.phone) : 'Membre'))
                      : 'Système'}
                  </span>
                </summary>
                <dl className="mt-2 grid gap-x-4 gap-y-1 rounded-2xl bg-panel-soft p-3 text-[12px] sm:grid-cols-[120px_minmax(0,1fr)]">
                  <dt className="font-bold text-muted">Objet</dt>
                  <dd className="font-mono break-all">
                    {entityLabel(entry.entityType)} · {entry.entityId}
                  </dd>
                  <dt className="font-bold text-muted">Avant</dt>
                  <dd className="font-mono break-all">{preview(entry.before)}</dd>
                  <dt className="font-bold text-muted">Après</dt>
                  <dd className="font-mono break-all">{preview(entry.after)}</dd>
                  <dt className="font-bold text-muted">Adresse IP</dt>
                  <dd className="font-mono">{entry.ip ?? '—'}</dd>
                </dl>
              </details>
            </li>
          ))}
        </ul>
      )}
      {page.nextCursor || search.suite ? (
        <div className="mt-4 flex justify-between text-[14px] font-bold">
          {search.suite ? (
            <Link
              href={hrefWith(current, { suite: undefined })}
              className="text-accent hover:underline"
            >
              ← Revenir au début
            </Link>
          ) : (
            <span />
          )}
          {page.nextCursor ? (
            <Link
              href={hrefWith(current, { suite: page.nextCursor })}
              className="text-accent hover:underline"
            >
              Actions plus anciennes →
            </Link>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
