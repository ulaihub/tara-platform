import type { Metadata } from 'next';
import Link from 'next/link';
import { Badge } from '@/components/ui';
import { requireStaff, staffApi } from '@/lib/dal';
import { dateTime } from '@/lib/format';
import { ROLE_LABELS } from '@/lib/navigation';
import { displayPhone } from '@/lib/phone';
import type { TeamMember } from '@/lib/schemas';
import { TEAM_ROLES } from '@/lib/team';
import { AddMemberForm, MemberActions } from './member-forms';
import { TeamHeader } from './tabs';

export const metadata: Metadata = { title: 'Équipe' };

/**
 * Équipe (H8) : membres, rôles et double authentification. Ajouter un membre lui donne
 * l'accès ; il se connecte avec son numéro et configure sa double authentification.
 */
export default async function TeamPage() {
  const session = await requireStaff(TEAM_ROLES);
  const members = await staffApi<TeamMember[]>('/admin/team');

  return (
    <div className="mx-auto max-w-[1280px]">
      <TeamHeader
        current="/equipe"
        aside={`${members.length} membre${members.length > 1 ? 's' : ''} · chaque action sensible est inscrite au journal.`}
      />
      <div className="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_420px]">
        <section className="overflow-hidden bo-glass rounded-[22px] shadow-card">
          <ul className="divide-y divide-line">
            {members.map((member) => (
              <li key={member.id} className="flex flex-wrap items-start gap-3 px-5 py-4">
                <div className="min-w-[220px] flex-1">
                  <p className="text-[15px] font-bold">
                    {member.fullName ?? displayPhone(member.phone)}
                    {member.id === session.userId ? (
                      <span className="ml-2 text-[12px] font-semibold text-muted">(vous)</span>
                    ) : null}
                  </p>
                  <p className="text-[13px] text-muted">
                    {displayPhone(member.phone)} · dernière connexion{' '}
                    {member.lastActiveAt ? dateTime(member.lastActiveAt) : 'jamais'}
                  </p>
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    {member.roles.map((role) => (
                      <Badge key={role} tone={role === 'ADMIN' ? 'accent' : 'neutral'}>
                        {ROLE_LABELS[role]}
                      </Badge>
                    ))}
                    {member.mfaEnabled ? (
                      <Badge tone="ok">Double authentification active</Badge>
                    ) : (
                      <Badge tone="warn">Double authentification à configurer</Badge>
                    )}
                  </div>
                </div>
                <MemberActions
                  userId={member.id}
                  roles={member.roles}
                  self={member.id === session.userId}
                />
              </li>
            ))}
          </ul>
        </section>
        <section className="bo-glass rounded-[22px] p-5 shadow-card">
          <h2 className="mb-1 font-display text-[17px] font-bold">Ajouter un membre</h2>
          <p className="mb-4 text-[13px] text-muted">
            Choisissez les rôles au plus juste : chacun ne voit que les écrans de son travail.{' '}
            <Link href="/equipe/journal" className="font-bold text-accent hover:underline">
              Voir le journal
            </Link>
          </p>
          <AddMemberForm />
        </section>
      </div>
    </div>
  );
}
