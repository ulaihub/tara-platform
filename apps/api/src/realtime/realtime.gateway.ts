import { Logger } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  type OnGatewayConnection,
  type OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import type { Namespace, Socket } from 'socket.io';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { SessionUserService } from '../auth/session-user.service.js';
import { AppError } from '../common/errors/app-error.js';
import { ACTIVE_RIDER_STATUSES } from '../dispatch/dispatch.service.js';
import { PresenceService } from '../dispatch/presence.service.js';
import { RiderLocationService } from '../dispatch/rider-location.service.js';
import type { OrderStatus } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PositionBody } from '../rider-app/rider-app.schemas.js';
import { OPS_ROOM, orderRoom, RealtimeService, userRoom } from './realtime.service.js';

interface SocketData {
  user: AuthUser;
  riderId: string | null;
  expiresAt: Date;
  lastLocationAt: number;
  subscriptions: number;
}

type Ack = { ok: true; [key: string]: unknown } | { ok: false; error: string };

const OrderRef = z.object({ orderId: z.uuid() });
/** Une position par socket au plus toutes les 2 s (l'app en envoie une toutes les 10 à 15 s). */
const MIN_LOCATION_INTERVAL_MS = 2_000;
/** Abonnements à des commandes par connexion. */
const MAX_SUBSCRIPTIONS = 50;

const OPS_ROLES = ['ADMIN', 'DISPATCHER', 'SUPPORT'] as const;

function isOps(user: AuthUser): boolean {
  return user.roles.some((role) => (OPS_ROLES as readonly string[]).includes(role));
}

function errorCode(error: unknown): string {
  return error instanceof AppError ? error.code : 'INTERNAL_ERROR';
}

/**
 * Temps réel (F1) : connexion Socket.IO sur `/realtime`, authentifiée par le même jeton
 * d'accès que l'API (`auth: { token }` à la connexion). Chaque utilisateur rejoint sa salle
 * personnelle (propositions de course, statuts de ses commandes) ; l'équipe rejoint la salle
 * des opérations ; une app peut suivre une commande à laquelle elle a accès. La connexion
 * est coupée à l'expiration du jeton : l'app se reconnecte avec un jeton renouvelé.
 */
@WebSocketGateway({ namespace: '/realtime', serveClient: false, maxHttpBufferSize: 16_000 })
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly sessions: SessionUserService,
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
    private readonly location: RiderLocationService,
    private readonly presence: PresenceService,
  ) {}

  afterInit(server: Namespace): void {
    this.realtime.attach(server);
    server.use((socket, next) => {
      this.authenticate(socket).then(
        () => next(),
        (error: unknown) => {
          const failure = new Error(errorCode(error)) as Error & { data?: unknown };
          failure.data = { code: errorCode(error) };
          next(failure);
        },
      );
    });
  }

  private async authenticate(socket: Socket): Promise<void> {
    const auth = socket.handshake.auth as { token?: unknown } | undefined;
    const header = socket.handshake.headers.authorization;
    const token =
      typeof auth?.token === 'string'
        ? auth.token
        : header?.startsWith('Bearer ')
          ? header.slice('Bearer '.length)
          : null;
    if (!token) throw AppError.unauthorized();
    const session = await this.sessions.resolve(token);
    const rider = session.user.roles.includes('RIDER')
      ? await this.prisma.riderProfile.findUnique({ where: { userId: session.user.id } })
      : null;
    const data: SocketData = {
      user: session.user,
      riderId: rider?.id ?? null,
      expiresAt: session.expiresAt,
      lastLocationAt: 0,
      subscriptions: 0,
    };
    socket.data = data;
  }

  handleConnection(socket: Socket): void {
    const data = socket.data as SocketData | undefined;
    if (!data?.user) {
      socket.disconnect(true);
      return;
    }
    void socket.join(userRoom(data.user.id));
    if (isOps(data.user)) void socket.join(OPS_ROOM);
    const timer = setTimeout(
      () => {
        socket.emit('session.expired', {});
        socket.disconnect(true);
      },
      Math.max(0, data.expiresAt.getTime() - Date.now()),
    );
    socket.once('disconnect', () => clearTimeout(timer));
  }

  /** Suivre une commande : statut et position du livreur en direct. */
  @SubscribeMessage('order.subscribe')
  async subscribe(@ConnectedSocket() socket: Socket, @MessageBody() body: unknown): Promise<Ack> {
    const data = socket.data as SocketData;
    const parsed = OrderRef.safeParse(body);
    if (!parsed.success) return { ok: false, error: 'VALIDATION_FAILED' };
    if (data.subscriptions >= MAX_SUBSCRIPTIONS) return { ok: false, error: 'RATE_LIMITED' };
    const order = await this.prisma.order.findUnique({ where: { id: parsed.data.orderId } });
    const allowed =
      order !== null &&
      (order.senderId === data.user.id ||
        (data.riderId !== null && order.riderId === data.riderId) ||
        isOps(data.user));
    if (!order || !allowed) return { ok: false, error: 'ORDER_NOT_FOUND' };
    await socket.join(orderRoom(order.id));
    data.subscriptions += 1;
    // Dernière position connue tout de suite : la carte n'attend pas le prochain envoi.
    const active = (ACTIVE_RIDER_STATUSES as readonly OrderStatus[]).includes(order.status);
    const position = active && order.riderId ? await this.presence.position(order.riderId) : null;
    return {
      ok: true,
      status: order.status,
      position: position
        ? {
            latitude: position.latitude,
            longitude: position.longitude,
            heading: position.heading ?? null,
            at: position.at.toISOString(),
          }
        : null,
    };
  }

  @SubscribeMessage('order.unsubscribe')
  async unsubscribe(@ConnectedSocket() socket: Socket, @MessageBody() body: unknown): Promise<Ack> {
    const parsed = OrderRef.safeParse(body);
    if (!parsed.success) return { ok: false, error: 'VALIDATION_FAILED' };
    await socket.leave(orderRoom(parsed.data.orderId));
    const data = socket.data as SocketData;
    data.subscriptions = Math.max(0, data.subscriptions - 1);
    return { ok: true };
  }

  /** Position du livreur (F1), même contenu que POST /v1/rider/location. */
  @SubscribeMessage('rider.location')
  async riderLocation(@ConnectedSocket() socket: Socket, @MessageBody() body: unknown): Promise<Ack> {
    const data = socket.data as SocketData;
    if (!data.riderId) return { ok: false, error: 'FORBIDDEN' };
    const now = Date.now();
    if (now - data.lastLocationAt < MIN_LOCATION_INTERVAL_MS) return { ok: false, error: 'RATE_LIMITED' };
    const parsed = PositionBody.safeParse(body);
    if (!parsed.success) return { ok: false, error: 'VALIDATION_FAILED' };
    data.lastLocationAt = now;
    try {
      await this.location.update(
        data.user.id,
        {
          latitude: parsed.data.latitude,
          longitude: parsed.data.longitude,
          heading: parsed.data.heading,
          speed: parsed.data.speed,
          accuracy: parsed.data.accuracy,
          at: parsed.data.recordedAt ? new Date(parsed.data.recordedAt) : new Date(),
        },
        data.riderId,
      );
      return { ok: true };
    } catch (error) {
      if (!(error instanceof AppError)) this.logger.error('Position non enregistrée', error);
      return { ok: false, error: errorCode(error) };
    }
  }
}
