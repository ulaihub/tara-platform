import type { INestApplicationContext } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';
import type { Server, ServerOptions } from 'socket.io';

/**
 * Socket.IO partagé entre les instances de l'API par Redis : un événement émis sur une
 * instance atteint les clients connectés aux autres. Les connexions Redis ne sont ouvertes
 * qu'à la création du serveur (la génération de l'OpenAPI n'en crée pas).
 */
export class RedisIoAdapter extends IoAdapter {
  private readonly connections: Redis[] = [];

  constructor(
    app: INestApplicationContext,
    private readonly redisUrl: string,
    private readonly channelPrefix: string,
  ) {
    super(app);
  }

  override createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, options) as Server;
    const pub = new Redis(this.redisUrl, { maxRetriesPerRequest: null });
    const sub = pub.duplicate();
    this.connections.push(pub, sub);
    server.adapter(createAdapter(pub, sub, { key: `${this.channelPrefix}:socket` }));
    return server;
  }

  override async close(server: Server): Promise<void> {
    await super.close(server);
    await Promise.all(
      this.connections.map((connection) => connection.quit().catch(() => undefined)),
    );
    this.connections.length = 0;
  }
}
