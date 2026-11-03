import {
  Inject,
  Injectable,
  Logger,
  type OnApplicationBootstrap,
  type OnModuleDestroy,
} from '@nestjs/common';
import { type Job, type JobsOptions, Queue, Worker } from 'bullmq';
import { Redis } from 'ioredis';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';

export type QueueName = 'dispatch' | 'notifications';

type Processor = (job: Job) => Promise<void>;

/**
 * Files de tâches persistantes (BullMQ) : tâches différées (expiration d'une offre de course),
 * nouvelles tentatives (notifications). Elles survivent à un redémarrage et se répartissent
 * entre les instances de l'API. Les traitements ne démarrent que si JOBS_ENABLED est vrai.
 */
@Injectable()
export class QueueService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(QueueService.name);
  private readonly queues = new Map<QueueName, Queue>();
  private readonly processors = new Map<QueueName, { processor: Processor; concurrency: number }>();
  private readonly workers: Worker[] = [];
  private readonly connections: Redis[] = [];

  constructor(@Inject(ENV) private readonly env: Env) {}

  get workersEnabled(): boolean {
    return this.env.JOBS_ENABLED;
  }

  private connection(): Redis {
    // BullMQ exige des connexions qui ne limitent pas les nouvelles tentatives.
    const connection = new Redis(this.env.REDIS_URL, { maxRetriesPerRequest: null });
    this.connections.push(connection);
    return connection;
  }

  private queue(name: QueueName): Queue {
    let queue = this.queues.get(name);
    if (!queue) {
      queue = new Queue(name, { connection: this.connection(), prefix: this.env.QUEUE_PREFIX });
      this.queues.set(name, queue);
    }
    return queue;
  }

  /** Déclare le traitement d'une file ; à appeler pendant l'initialisation des modules. */
  register(name: QueueName, processor: Processor, concurrency = 10): void {
    this.processors.set(name, { processor, concurrency });
  }

  async add(
    name: QueueName,
    jobName: string,
    data: object,
    options: JobsOptions = {},
  ): Promise<void> {
    await this.queue(name).add(jobName, data, {
      removeOnComplete: 1_000,
      removeOnFail: 5_000,
      ...options,
    });
  }

  onApplicationBootstrap(): void {
    if (!this.env.JOBS_ENABLED) return;
    for (const [name, { processor, concurrency }] of this.processors) {
      const worker = new Worker(name, processor, {
        connection: this.connection(),
        prefix: this.env.QUEUE_PREFIX,
        concurrency,
      });
      worker.on('failed', (job, error) => {
        this.logger.warn(`Tâche ${name}/${job?.name ?? '?'} en échec : ${error.message}`);
      });
      this.workers.push(worker);
    }
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.all(this.workers.map((worker) => worker.close()));
    await Promise.all([...this.queues.values()].map((queue) => queue.close()));
    await Promise.all(
      this.connections.map((connection) => connection.quit().catch(() => undefined)),
    );
  }
}
