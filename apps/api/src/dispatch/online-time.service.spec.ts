import { describe, expect, it } from 'vitest';
import { bucketStarts, periodStart } from '../rider-app/rider-orders.service.js';
import { OnlineTimeService } from './online-time.service.js';

const TTL_SECONDS = 90;

/** Faux Prisma et faux Redis, juste ce que le service utilise. */
function fakes() {
  type Session = {
    id: string;
    riderId: string;
    startedAt: Date;
    lastSeenAt: Date;
    endedAt: Date | null;
  };
  const sessions: Session[] = [];
  const keys = new Set<string>();
  const prisma = {
    riderOnlineSession: {
      findFirst: ({ where }: { where: { riderId: string } }) =>
        Promise.resolve(
          sessions.find((s) => s.riderId === where.riderId && s.endedAt === null) ?? null,
        ),
      update: ({ where, data }: { where: { id: string }; data: Partial<Session> }) => {
        const session = sessions.find((s) => s.id === where.id);
        Object.assign(session ?? {}, data);
        return Promise.resolve(session);
      },
      create: ({ data }: { data: Omit<Session, 'id' | 'endedAt'> }) => {
        const session = { id: String(sessions.length + 1), endedAt: null, ...data };
        sessions.push(session);
        return Promise.resolve(session);
      },
      findMany: ({ where }: { where: { riderId: string } }) =>
        Promise.resolve(sessions.filter((s) => s.riderId === where.riderId)),
    },
  };
  const redis = {
    set: (key: string) => Promise.resolve(keys.has(key) ? null : (keys.add(key), 'OK')),
    del: (key: string) => Promise.resolve(keys.delete(key) ? 1 : 0),
  };
  const service = new OnlineTimeService(
    prisma as never,
    redis as never,
    { RIDER_POSITION_TTL_SECONDS: TTL_SECONDS } as never,
  );
  return { service, sessions, keys };
}

const at = (minutes: number): Date => new Date(Date.UTC(2026, 10, 3, 8, 0) + minutes * 60_000);

/** Positions reçues chaque minute, de `from` à `to` (le délai entre écritures est simulé). */
async function positions(
  { service, keys }: ReturnType<typeof fakes>,
  from: number,
  to: number,
): Promise<void> {
  for (let minute = from; minute <= to; minute++) {
    keys.clear();
    await service.touch('r1', at(minute));
  }
}

describe('temps en ligne des livreurs (E9)', () => {
  it('compte une session ouverte puis fermée', async () => {
    const fake = fakes();
    const { service } = fake;
    await service.start('r1', at(0));
    await positions(fake, 1, 44);
    await service.stop('r1', at(45));
    expect(await service.seconds('r1', at(-60), at(120), at(120))).toBe(45 * 60);
    // Seulement la partie comprise dans la période demandée.
    expect(await service.seconds('r1', at(30), at(120), at(120))).toBe(15 * 60);
  });

  it('arrête une session abandonnée à la dernière position reçue', async () => {
    const fake = fakes();
    const { service } = fake;
    await service.start('r1', at(0));
    await positions(fake, 1, 10);
    // Plus aucune nouvelle pendant une heure : seules les 10 minutes vues comptent.
    expect(await service.seconds('r1', at(-60), at(70), at(70))).toBe(10 * 60);
    // Au retour en ligne, l'ancienne session est close à sa dernière position.
    await service.start('r1', at(70));
    await positions(fake, 71, 79);
    await service.stop('r1', at(80));
    expect(await service.seconds('r1', at(-60), at(120), at(120))).toBe(20 * 60);
  });

  it('compte jusqu’à maintenant une session encore vivante', async () => {
    const { service } = fakes();
    await service.start('r1', at(0));
    expect(await service.seconds('r1', at(-60), at(1), at(1))).toBe(60);
  });
});

describe('tranches de l’histogramme des gains', () => {
  it('jour : 8 tranches de 2 h à partir de 6 h, heure du Cameroun', () => {
    const now = new Date('2026-11-03T15:00:00Z');
    const starts = bucketStarts('day', periodStart('day', now));
    expect(starts).toHaveLength(8);
    expect(starts[0]?.toISOString()).toBe('2026-11-03T05:00:00.000Z'); // 6 h à Douala
    expect(starts[7]?.toISOString()).toBe('2026-11-03T19:00:00.000Z'); // 20 h
  });

  it('mois : semaines du 1er, 8, 15, 22 et 29 quand ce jour existe', () => {
    const november = bucketStarts('month', periodStart('month', new Date('2026-11-20T12:00:00Z')));
    expect(november.map((d) => d.toISOString().slice(0, 10))).toEqual([
      '2026-10-31',
      '2026-11-07',
      '2026-11-14',
      '2026-11-21',
      '2026-11-28',
    ]);
    const february = bucketStarts('month', periodStart('month', new Date('2026-02-10T12:00:00Z')));
    expect(february).toHaveLength(4);
  });
});
