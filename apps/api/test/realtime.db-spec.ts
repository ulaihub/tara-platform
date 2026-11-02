import type { AddressInfo } from 'node:net';
import request from 'supertest';
import { io, type Socket } from 'socket.io-client';
import {
  createTestApp,
  type SignedIn,
  signIn,
  staffUser,
  type TestContext,
} from './helpers/app.js';
import {
  merchant,
  nearAkwa,
  placeOrder,
  setupDouala,
  type TestMerchant,
} from './helpers/orders.js';
import { activeRider, goOnline, resetPresence } from './helpers/riders.js';

/** Prochain événement d'un nom donné, avec délai maximal. */
function next<T>(socket: Socket, event: string, timeoutMs = 3_000): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Pas d'événement ${event}`)), timeoutMs);
    socket.once(event, (payload: T) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

describe('Temps réel (F1)', () => {
  let ctx: TestContext;
  let url: string;
  let admin: SignedIn;
  let shop: TestMerchant;
  const sockets: Socket[] = [];

  beforeAll(async () => {
    ctx = await createTestApp();
    await ctx.app.listen(0);
    const { port } = ctx.app.getHttpServer().address() as AddressInfo;
    url = `http://127.0.0.1:${port}/realtime`;
    admin = await staffUser(ctx, ['ADMIN']);
    await setupDouala(ctx, admin);
    shop = await merchant(ctx);
  });
  beforeEach(async () => {
    await resetPresence();
  });
  afterEach(() => {
    for (const socket of sockets.splice(0)) socket.disconnect();
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  async function connect(user: SignedIn | null): Promise<Socket> {
    const socket = io(url, {
      transports: ['websocket'],
      auth: user ? { token: user.accessToken } : {},
      reconnection: false,
    });
    sockets.push(socket);
    await new Promise<void>((resolve, reject) => {
      socket.once('connect', () => resolve());
      socket.once('connect_error', (error) => reject(error));
    });
    return socket;
  }

  it('refuse une connexion sans jeton valide', async () => {
    await expect(connect(null)).rejects.toThrow('UNAUTHENTICATED');
    await expect(connect({ ...admin, accessToken: 'faux.jeton.signe' })).rejects.toThrow(
      'UNAUTHENTICATED',
    );
  });

  it('pousse la proposition au livreur, puis statut et position à l’expéditeur', async () => {
    const rider = await activeRider(ctx);
    await goOnline(ctx, rider, nearAkwa(0.001));
    const riderSocket = await connect(rider);
    const senderSocket = await connect(shop);

    const offerEvent = next<{ id: string; orderId: string; expiresAt: string }>(
      riderSocket,
      'offer.new',
    );
    const order = await placeOrder(ctx, shop);
    const offer = await offerEvent;
    expect(offer.orderId).toBe(order.id);

    const ack = await senderSocket
      .timeout(3_000)
      .emitWithAck('order.subscribe', { orderId: order.id });
    expect(ack).toMatchObject({ ok: true, status: 'SEARCHING_RIDER', position: null });

    const assigned = next<{ status: string }>(senderSocket, 'order.status');
    await request(ctx.http).post(`/v1/rider/offers/${offer.id}/accept`).set(rider.auth).expect(200);
    expect(await assigned).toMatchObject({ status: 'ASSIGNED' });

    const moved = next<{ latitude: number; orderId: string }>(senderSocket, 'rider.position');
    const sent = await riderSocket
      .timeout(3_000)
      .emitWithAck('rider.location', { ...nearAkwa(0.0015), heading: 90 });
    expect(sent).toEqual({ ok: true });
    expect(await moved).toMatchObject({ orderId: order.id, latitude: nearAkwa(0.0015).latitude });

    // Trop rapproché : ignoré (une position toutes les 10 à 15 s suffit).
    expect(await riderSocket.timeout(3_000).emitWithAck('rider.location', nearAkwa(0.002))).toEqual(
      {
        ok: false,
        error: 'RATE_LIMITED',
      },
    );

    // Un abonné arrivé plus tard reçoit tout de suite la dernière position.
    const late = await connect(shop);
    const lateAck = await late.timeout(3_000).emitWithAck('order.subscribe', { orderId: order.id });
    expect(lateAck).toMatchObject({
      ok: true,
      status: 'ASSIGNED',
      position: { latitude: nearAkwa(0.0015).latitude },
    });
  });

  it('ne laisse suivre une commande qu’à ceux qui y ont accès', async () => {
    const order = await placeOrder(ctx, shop);
    const stranger = await connect(await signIn(ctx));
    expect(
      await stranger.timeout(3_000).emitWithAck('order.subscribe', { orderId: order.id }),
    ).toEqual({
      ok: false,
      error: 'ORDER_NOT_FOUND',
    });
    expect(await stranger.timeout(3_000).emitWithAck('rider.location', nearAkwa(0))).toEqual({
      ok: false,
      error: 'FORBIDDEN',
    });
    const ops = await connect(admin);
    expect(
      await ops.timeout(3_000).emitWithAck('order.subscribe', { orderId: order.id }),
    ).toMatchObject({ ok: true });
  });
});
