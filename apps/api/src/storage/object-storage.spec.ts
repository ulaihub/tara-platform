import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { S3Storage } from './object-storage.js';

/**
 * Serveur S3 minimal en mémoire (adresses « endpoint/bucket/clé ») : vérifie ce que le
 * stockage envoie et relit, sans compte chez un hébergeur. Les signatures ne sont pas
 * vérifiées ici : c'est le rôle du vrai service.
 */
function fakeS3(
  objects: Map<string, Buffer>,
  seen: { method: string; path: string; auth: boolean }[],
) {
  return createServer((req, res) => {
    const path = decodeURIComponent((req.url ?? '').split('?')[0] ?? '');
    seen.push({
      method: req.method ?? '',
      path,
      auth: (req.headers.authorization ?? '').startsWith('AWS4-HMAC-SHA256'),
    });
    const chunks: Buffer[] = [];
    req.on('data', (chunk: Buffer) => chunks.push(chunk));
    req.on('end', () => {
      if (req.method === 'PUT') {
        objects.set(path, Buffer.concat(chunks));
        res.writeHead(200, { ETag: '"1"' }).end();
      } else if (req.method === 'GET') {
        const body = objects.get(path);
        if (!body) {
          res
            .writeHead(404, { 'Content-Type': 'application/xml' })
            .end('<Error><Code>NoSuchKey</Code><Message>absent</Message></Error>');
          return;
        }
        res.writeHead(200, { 'Content-Length': body.length }).end(body);
      } else if (req.method === 'DELETE') {
        objects.delete(path);
        res.writeHead(204).end();
      } else {
        res.writeHead(405).end();
      }
    });
  });
}

describe('S3Storage', () => {
  const objects = new Map<string, Buffer>();
  const seen: { method: string; path: string; auth: boolean }[] = [];
  let server: Server;
  let storage: S3Storage;

  beforeAll(async () => {
    server = fakeS3(objects, seen);
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const { port } = server.address() as AddressInfo;
    storage = new S3Storage({
      endpoint: `http://127.0.0.1:${port}`,
      region: 'us-east-1',
      bucket: 'tara-fichiers',
      accessKeyId: 'cle',
      secretAccessKey: 'secret',
      forcePathStyle: true,
    });
  });
  afterAll(() => {
    server.close();
  });

  it('enregistre, relit et supprime un fichier dans le compartiment, requêtes signées', async () => {
    const body = Buffer.from([0xff, 0xd8, 0xff, 1, 2, 3]);
    await storage.put('proof-photo/2026/11/abc', body);
    expect(objects.get('/tara-fichiers/proof-photo/2026/11/abc')?.equals(body)).toBe(true);
    expect((await storage.get('proof-photo/2026/11/abc')).equals(body)).toBe(true);
    await storage.delete('proof-photo/2026/11/abc');
    expect(objects.has('/tara-fichiers/proof-photo/2026/11/abc')).toBe(false);
    expect(seen.map((r) => r.method)).toEqual(['PUT', 'GET', 'DELETE']);
    expect(seen.every((r) => r.auth)).toBe(true);
  });

  it('signale clairement un fichier absent', async () => {
    await expect(storage.get('kyc-document/absent')).rejects.toThrow(/introuvable/);
  });
});
