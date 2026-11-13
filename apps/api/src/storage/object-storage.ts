import { randomUUID } from 'node:crypto';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  NoSuchKey,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, resolve, sep } from 'node:path';

export const OBJECT_STORAGE = Symbol('OBJECT_STORAGE');

/** Stockage d'objets binaires : disque en développement, compatible S3 en production. */
export interface ObjectStorage {
  put(key: string, body: Buffer): Promise<void>;
  get(key: string): Promise<Buffer>;
  delete(key: string): Promise<void>;
}

/** Stockage sur disque local, pour le développement et les tests. */
export class LocalFsStorage implements ObjectStorage {
  private readonly root: string;

  constructor(directory: string) {
    this.root = resolve(directory);
  }

  private pathOf(key: string): string {
    const path = resolve(this.root, key);
    if (!path.startsWith(this.root + sep)) throw new Error(`Clé de stockage invalide : ${key}`);
    return path;
  }

  async put(key: string, body: Buffer): Promise<void> {
    const path = this.pathOf(key);
    await mkdir(dirname(path), { recursive: true });
    // Écriture puis renommage : un fichier n'est jamais lu à moitié écrit (rotation de clé).
    const temporary = `${path}.${randomUUID()}.tmp`;
    await writeFile(temporary, body);
    await rename(temporary, path);
  }

  get(key: string): Promise<Buffer> {
    return readFile(this.pathOf(key));
  }

  async delete(key: string): Promise<void> {
    await rm(this.pathOf(key), { force: true });
  }
}

export interface S3StorageOptions {
  endpoint?: string | undefined;
  region: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  forcePathStyle: boolean;
}

/**
 * Stockage objet compatible S3 (Amazon S3, Scaleway, OVHcloud, Cloudflare R2, MinIO…).
 * Les pièces d'identité y arrivent déjà chiffrées par l'API ; le compartiment reste privé
 * (aucune URL publique : les fichiers ne sortent que par l'API, après contrôle des droits).
 */
export class S3Storage implements ObjectStorage {
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor(options: S3StorageOptions) {
    this.bucket = options.bucket;
    this.client = new S3Client({
      ...(options.endpoint ? { endpoint: options.endpoint } : {}),
      region: options.region,
      forcePathStyle: options.forcePathStyle,
      credentials: {
        accessKeyId: options.accessKeyId,
        secretAccessKey: options.secretAccessKey,
      },
      maxAttempts: 3,
    });
  }

  async put(key: string, body: Buffer): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentLength: body.length,
      }),
    );
  }

  async get(key: string): Promise<Buffer> {
    try {
      const object = await this.client.send(
        new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      if (!object.Body) throw new Error(`Objet vide : ${key}`);
      return Buffer.from(await object.Body.transformToByteArray());
    } catch (error) {
      if (error instanceof NoSuchKey) throw new Error(`Objet introuvable : ${key}`);
      throw error;
    }
  }

  async delete(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }
}
