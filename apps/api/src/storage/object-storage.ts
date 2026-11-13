import { randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, resolve, sep } from 'node:path';

export const OBJECT_STORAGE = Symbol('OBJECT_STORAGE');

/** Stockage d'objets binaires. Un stockage compatible S3 remplacera le disque en production. */
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
