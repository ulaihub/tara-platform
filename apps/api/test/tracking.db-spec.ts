import request from 'supertest';
import { CourseTrackService } from '../src/tracking/course-track.service.js';
import { createTestApp, type SignedIn, staffUser, type TestContext } from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  type PlacedOrder,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import {
  activeRider,
  goOnline,
  proofPhoto,
  resetPresence,
  type TestRider,
} from './helpers/riders.js';

const HERE = nearAkwa(0.001);
const MINUTE = 60_000;

describe('Trajet des courses (sécurité, litiges, fraude)', () => {
  let ctx: TestContext;
  let admin: SignedIn;
  let support: SignedIn;
  let shop: TestMerchant;
  let tracks: CourseTrackService;

  beforeAll(async () => {
    ctx = await createTestApp();
    admin = await staffUser(ctx, ['ADMIN']);
    support = await staffUser(ctx, ['SUPPORT']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
    tracks = ctx.app.get(CourseTrackService);
  });
  beforeEach(async () => {
    await resetPresence();
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  async function assigned(): Promise<{ rider: TestRider; order: PlacedOrder }> {
    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, HERE);
    const order = await placeOrder(ctx, shop);
    const offer = await ctx.prisma.dispatchOffer.findFirstOrThrow({
      where: { orderId: order.id, riderId: rider.riderId },
    });
    await request(ctx.http).post(`/v1/rider/offers/${offer.id}/accept`).set(rider.auth).expect(200);
    return { rider, order };
  }

  async function addresses(rider: TestRider, order: PlacedOrder) {
    const res = await request(ctx.http)
      .get(`/v1/rider/orders/${order.id}`)
      .set(rider.auth)
      .expect(200);
    const ll = (a: { latitude: number; longitude: number }) => ({
      latitude: a.latitude,
      longitude: a.longitude,
    });
    return { pickup: ll(res.body.pickup), dropoff: ll(res.body.dropoff) };
  }

  async function pickUp(rider: TestRider, order: PlacedOrder, at = HERE): Promise<void> {
    const photoKey = await proofPhoto(ctx, rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/pickup`)
      .set(rider.auth)
      .send({ pickupCode: order.pickupCode, photoKey, ...at })
      .expect(200);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/depart`)
      .set(rider.auth)
      .send(at)
      .expect(200);
  }

  const point = (minutesAgo: number, place = HERE, extra: Record<string, unknown> = {}) => ({
    ...place,
    recordedAt: new Date(Date.now() - minutesAgo * MINUTE).toISOString(),
    ...extra,
  });

  const alertsOf = (orderId: string) =>
    ctx.prisma.courseAlert.findMany({ where: { orderId }, orderBy: { createdAt: 'asc' } });

  it('enregistre le trajet pendant la course seulement, et les positions gardées hors réseau', async () => {
    const { rider, order } = await assigned();
    await request(ctx.http).post('/v1/rider/location').set(rider.auth).send(HERE).expect(204);
    // Un point toutes les ~10 s au plus : la position suivante, aussitôt, n'est pas doublée.
    await request(ctx.http).post('/v1/rider/location').set(rider.auth).send(HERE).expect(204);
    expect(await ctx.prisma.courseTrackPoint.count({ where: { orderId: order.id } })).toBe(1);

    const batch = { points: [point(30), point(1.5), point(1)] };
    const sent = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/track`)
      .set(rider.auth)
      .send(batch)
      .expect(200);
    // Le point d'avant l'acceptation n'appartient pas à la course.
    expect(sent.body).toEqual({ accepted: 2, ignored: 1 });
    const again = await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/track`)
      .set(rider.auth)
      .send(batch)
      .expect(200);
    expect(again.body).toEqual({ accepted: 0, ignored: 1 });
    expect(
      await ctx.prisma.courseTrackPoint.count({ where: { orderId: order.id, late: true } }),
    ).toBe(2);

    // En ligne sans course : aucune position enregistrée.
    const idle = await activeRider(ctx);
    await goOnline(ctx, idle, HERE);
    await request(ctx.http).post('/v1/rider/location').set(idle.auth).send(HERE).expect(204);
    expect(await ctx.prisma.courseTrackPoint.count({ where: { riderId: idle.riderId } })).toBe(0);

    const other = await activeRider(ctx);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/track`)
      .set(other.auth)
      .send(batch)
      .expect(404);
  });

  it('alerte le support : position simulée, enlèvement loin de l’adresse ; prise en charge tracée', async () => {
    const { rider, order } = await assigned();
    await request(ctx.http)
      .post('/v1/rider/location')
      .set(rider.auth)
      .send({ ...HERE, mocked: true })
      .expect(204);
    const { pickup } = await addresses(rider, order);
    await pickUp(rider, order, { latitude: pickup.latitude + 0.01, longitude: pickup.longitude });

    const alerts = await alertsOf(order.id);
    expect(alerts.map((a) => a.dedupeKey)).toEqual(['MOCK_LOCATION', 'ACTION_FAR:PICKUP']);
    const far = alerts[1]?.details as { meters: number } | undefined;
    expect(far?.meters).toBeGreaterThan(1000);

    const open = await request(ctx.http)
      .get('/v1/admin/course-alerts')
      .set(support.auth)
      .expect(200);
    expect(open.body.map((a: { orderId: string }) => a.orderId)).toContain(order.id);
    const id = alerts[0]?.id as string;
    const acknowledged = await request(ctx.http)
      .post(`/v1/admin/course-alerts/${id}/acknowledge`)
      .set(support.auth)
      .send({ note: 'Livreur appelé : application de localisation désinstallée.' })
      .expect(200);
    expect(acknowledged.body.acknowledgedAt).not.toBeNull();
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'course_alert.acknowledged', entityId: id },
      }),
    ).toBe(1);
  });

  it('résume le trajet à la fin ; consultation réservée à l’équipe et tracée', async () => {
    const { rider, order } = await assigned();
    const { pickup, dropoff } = await addresses(rider, order);
    await pickUp(rider, order, pickup);
    // Course commencée il y a 30 minutes : trajet réaliste (≈ 2,5 km toutes les 10 minutes).
    await ctx.prisma.order.update({
      where: { id: order.id },
      data: { assignedAt: new Date(Date.now() - 30 * MINUTE) },
    });
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/track`)
      .set(rider.auth)
      .send({
        points: [
          point(20, pickup),
          point(10, {
            latitude: (pickup.latitude + dropoff.latitude) / 2,
            longitude: (pickup.longitude + dropoff.longitude) / 2,
          }),
          point(1, dropoff),
        ],
      })
      .expect(200);
    const text = ctx.sms.lastTo(order.recipientPhone)?.text ?? '';
    const deliveryCode = /donner au livreur : (\d{4})/.exec(text)?.[1];
    const photoKey = await proofPhoto(ctx, rider);
    await request(ctx.http)
      .post(`/v1/rider/orders/${order.id}/deliver`)
      .set(rider.auth)
      .send({ deliveryCode, photoKey, ...dropoff })
      .expect(200);

    const summary = await ctx.prisma.courseTrack.findUniqueOrThrow({
      where: { orderId_riderId: { orderId: order.id, riderId: rider.riderId } },
    });
    expect(summary.pointCount).toBeGreaterThanOrEqual(3);
    expect(summary.distanceMeters).toBeGreaterThan(0);

    const view = await request(ctx.http)
      .get(`/v1/admin/orders/${order.id}/track`)
      .set(support.auth)
      .expect(200);
    expect(view.body.points.length).toBe(summary.pointCount);
    expect(view.body.summaries[0].distanceMeters).toBe(summary.distanceMeters);
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'order.track_viewed', entityId: order.id },
      }),
    ).toBe(1);

    await request(ctx.http).get(`/v1/admin/orders/${order.id}/track`).set(rider.auth).expect(403);
    await request(ctx.http).get(`/v1/admin/orders/${order.id}/track`).set(shop.auth).expect(403);

    // Droit d'accès : le livreur retrouve ses trajets dans l'export de ses données.
    const exported = await request(ctx.http).get('/v1/me/export').set(rider.auth).expect(200);
    const mine = exported.body.rider.courseTracks as { reference: string }[];
    expect(mine.filter((p) => p.reference === order.reference)).toHaveLength(summary.pointCount);
  });

  it('efface les points après 90 jours, sauf litige ou incident ouvert', async () => {
    const quiet = await assigned();
    const disputed = await assigned();
    const old = new Date(Date.now() - 100 * 24 * 60 * MINUTE);
    for (const { rider, order } of [quiet, disputed]) {
      await ctx.prisma.courseTrackPoint.createMany({
        data: [0, 10, 20].map((s) => ({
          orderId: order.id,
          riderId: rider.riderId,
          recordedAt: new Date(old.getTime() + s * 1000),
          latitude: HERE.latitude,
          longitude: HERE.longitude,
        })),
      });
    }
    await ctx.prisma.courseTrack.create({
      data: {
        orderId: quiet.order.id,
        riderId: quiet.rider.riderId,
        pointCount: 3,
        distanceMeters: 0,
        startedAt: old,
        endedAt: old,
        longestGapSeconds: 10,
        longestStopSeconds: 20,
        mockedPoints: 0,
        computedAt: old,
      },
    });
    await ctx.prisma.ticket.create({
      data: {
        orderId: disputed.order.id,
        openedById: support.userId,
        contactPhone: support.phone,
        category: 'LOST_PARCEL',
        subject: 'Colis non reçu selon le client',
      },
    });

    await tracks.purge(new Date());

    expect(await ctx.prisma.courseTrackPoint.count({ where: { orderId: quiet.order.id } })).toBe(0);
    expect(await ctx.prisma.courseTrackPoint.count({ where: { orderId: disputed.order.id } })).toBe(
      3,
    );
    const summary = await ctx.prisma.courseTrack.findUniqueOrThrow({
      where: { orderId_riderId: { orderId: quiet.order.id, riderId: quiet.rider.riderId } },
    });
    expect(summary.pointsPurgedAt).not.toBeNull();
  });

  it('surveille les courses : long arrêt avec le colis à bord, trajet coupé', async () => {
    const stopped = await assigned();
    const { pickup, dropoff } = await addresses(stopped.rider, stopped.order);
    await pickUp(stopped.rider, stopped.order, pickup);
    await ctx.prisma.order.update({
      where: { id: stopped.order.id },
      data: { assignedAt: new Date(Date.now() - 40 * MINUTE) },
    });
    const elsewhere = {
      latitude: pickup.latitude,
      longitude: Math.max(pickup.longitude, dropoff.longitude) + 0.02,
    };
    await request(ctx.http)
      .post(`/v1/rider/orders/${stopped.order.id}/track`)
      .set(stopped.rider.auth)
      .send({ points: [20, 15, 10, 5, 0.5].map((m) => point(m, elsewhere)) })
      .expect(200);

    const silent = await assigned();
    await ctx.prisma.order.update({
      where: { id: silent.order.id },
      data: { assignedAt: new Date(Date.now() - 30 * MINUTE) },
    });

    await tracks.scan(new Date());

    expect((await alertsOf(stopped.order.id)).map((a) => a.kind)).toContain('LONG_STOP');
    expect((await alertsOf(silent.order.id)).map((a) => a.kind)).toEqual(['TRACK_GAP']);
    // Une seule alerte par sujet : le passage suivant n'en recrée pas.
    await tracks.scan(new Date());
    expect(await alertsOf(silent.order.id)).toHaveLength(1);
  });

  it('signale une prime d’approche payée sans trajet correspondant jusqu’au vendeur', async () => {
    // Livreur à environ 3,9 km du vendeur : au-delà du seuil de la prime d'approche.
    const far = nearAkwa(0.035);
    async function course(path: { latitude: number; longitude: number }[]) {
      const rider = await activeRider(ctx);
      await goOnline(ctx, rider, far);
      const order = await placeOrder(ctx, shop);
      const offer = await ctx.prisma.dispatchOffer.findFirstOrThrow({
        where: { orderId: order.id, riderId: rider.riderId },
      });
      expect(offer.approachBonus).toBeGreaterThan(0);
      await request(ctx.http)
        .post(`/v1/rider/offers/${offer.id}/accept`)
        .set(rider.auth)
        .expect(200);
      await ctx.prisma.order.update({
        where: { id: order.id },
        data: { assignedAt: new Date(Date.now() - 12 * MINUTE) },
      });
      const { pickup } = await addresses(rider, order);
      await request(ctx.http)
        .post(`/v1/rider/orders/${order.id}/track`)
        .set(rider.auth)
        .send({ points: path.map((place, i) => point(11 - i, place)) })
        .expect(200);
      await pickUp(rider, order, pickup);
      await tracks.finish(order.id, rider.riderId);
      return (await alertsOf(order.id)).map((alert) => alert.kind);
    }
    const akwa = nearAkwa(0);
    // Trajet réel : de sa position jusqu'au vendeur, une position par minute.
    const driven = Array.from({ length: 10 }, (_, i) => ({
      latitude: far.latitude + ((akwa.latitude - far.latitude) * i) / 9,
      longitude: far.longitude + ((akwa.longitude - far.longitude) * i) / 9,
    }));
    expect(await course(driven)).not.toContain('APPROACH_BONUS');
    // Position annoncée loin, mais le téléphone ne bouge pas d'à côté du vendeur.
    expect(await course(Array.from({ length: 10 }, () => akwa))).toContain('APPROACH_BONUS');
  });

  it('le compte de l’API ne peut pas modifier un point de trajet', async () => {
    await expect(
      ctx.prisma
        .$executeRaw`UPDATE course_track_points SET latitude = 0 WHERE id = (SELECT min(id) FROM course_track_points)`,
    ).rejects.toThrow(/permission denied/i);
  });
});
