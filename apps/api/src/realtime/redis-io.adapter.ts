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
    /** Origines web autorisées (back-office, suivi) ; les apps mobiles n'en envoient pas. */
    private readonly corsOrigins: string[] = [],
  ) {
    super(app);
  }

  override createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, {
      ...options,
      cors: this.corsOrigins.length > 0 ? { origin: this.corsOrigins } : { origin: false },
    } as ServerOptions) as Server;
    const pub = new Redis(this.redisUrl, { maxRetriesPerRequest: null });
    const sub = pub.duplicate();
    this.connections.push(pub, sub);
    server.adapter(createAdapter(pub, sub, { key: `${this.channelPrefix}:socket` }));
    return server;
  }

  override async close(server: Server): Promise<void> {
    await super.close(server);
    // L'adaptateur s'abonne à ses canaux sans attendre la réponse : fermer une connexion
    // encore en cours d'ouverture rejetterait ces abonnements, sans personne pour les
    // rattraper (application arrêtée juste après son démarrage).
    await Promise.all(
      this.connections.map(async (connection) => {
        await whenSettled(connection);
        await connection.quit().catch(() => undefined);
      }),
    );
    this.connections.length = 0;
  }
}

/** Connexion prête, fermée ou en échec (5 s au plus) : plus aucune ouverture en cours. */
function whenSettled(connection: Redis): Promise<void> {
  if (connection.status === 'ready' || connection.status === 'end') return Promise.resolve();
  return new Promise((resolve) => {
    const done = (): void => {
      clearTimeout(timer);
      connection.off('ready', done).off('end', done).off('error', done);
      resolve();
    };
    const timer = setTimeout(done, 5_000);
    connection.once('ready', done).once('end', done).once('error', done);
  });
}
