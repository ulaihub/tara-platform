import { randomBytes } from 'node:crypto';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { MFA_KEY_PURPOSE } from '../src/auth/mfa.service.js';
import { decrypt, deriveKey, encrypt } from '../src/common/crypto.js';
import { ENV } from '../src/config/config.module.js';
import type { Env } from '../src/config/env.js';
import { KeyRotationService } from '../src/storage/key-rotation.service.js';
import { MediaService } from '../src/storage/media.service.js';
import { LocalFsStorage } from '../src/storage/object-storage.js';
import { createTestApp, randomPhone, type TestContext } from './helpers/app.js';

const OLD_KEY = randomBytes(32).toString('base64');
const NEW_KEY = randomBytes(32).toString('base64');
const PDF = Buffer.from('%PDF-1.4\nCarte nationale d’identité (fictive)\n%%EOF');

/** Application dont le stockage chiffré est isolé dans un dossier propre à ce test. */
function app(dir: string, current: string, previous?: string): Promise<TestContext> {
  return createTestApp({
    STORAGE_LOCAL_DIR: dir,
    STORAGE_ENCRYPTION_KEY: current,
    ...(previous ? { STORAGE_ENCRYPTION_KEY_PREVIOUS: previous } : {}),
  });
}

describe('Rotation de la clé de chiffrement du stockage', () => {
  const dir = mkdtempSync(join(tmpdir(), 'tara-rotation-'));
  let before: TestContext;
  let during: TestContext;
  let after: TestContext;
  let ownerId: string;
  let fileKey: string;
  let staffId: string;
  const totpSecret = 'JBSWY3DPEHPK3PXP';

  beforeAll(async () => {
    before = await app(dir, OLD_KEY);
    const owner = await before.prisma.user.create({ data: { phone: randomPhone() } });
    ownerId = owner.id;
    // Pièce d'identité chiffrée avec l'ancienne clé, secret TOTP d'un membre de l'équipe aussi.
    fileKey = (
      await before.app.get(MediaService).store(ownerId, 'KYC_DOCUMENT', {
        buffer: PDF,
        mimetype: 'application/pdf',
        size: PDF.length,
      })
    ).key;
    const oldTotpKey = deriveKey(Buffer.from(OLD_KEY, 'base64'), MFA_KEY_PURPOSE);
    staffId = (
      await before.prisma.user.create({
        data: {
          phone: randomPhone(),
          roles: ['ADMIN'],
          totpSecretEnc: encrypt(oldTotpKey, Buffer.from(totpSecret)).toString('base64'),
        },
      })
    ).id;
    during = await app(dir, NEW_KEY, OLD_KEY);
  });

  afterAll(async () => {
    await before.app.close();
    await during.app.close();
    await after?.app.close();
  });

  it('pendant la rotation, l’API lit encore ce qui est chiffré avec l’ancienne clé', async () => {
    const read = await during.app.get(MediaService).read(fileKey);
    expect(read.buffer.equals(PDF)).toBe(true);
  });

  it('rechiffre fichiers et secrets avec la nouvelle clé, puis ne refait rien', async () => {
    const env = during.app.get<Env>(ENV);
    const rotation = new KeyRotationService(during.prisma, new LocalFsStorage(dir), env);

    const first = await rotation.rotate();
    expect(first.files.rotated).toBeGreaterThanOrEqual(1);
    expect(first.files.failed).not.toContain(fileKey);
    expect(first.totpSecrets.failed).not.toContain(staffId);

    const stored = await new LocalFsStorage(dir).get(fileKey);
    expect(decrypt(Buffer.from(NEW_KEY, 'base64'), stored).equals(PDF)).toBe(true);
    const staff = await during.prisma.user.findUniqueOrThrow({ where: { id: staffId } });
    const newTotpKey = deriveKey(Buffer.from(NEW_KEY, 'base64'), MFA_KEY_PURPOSE);
    expect(decrypt(newTotpKey, Buffer.from(staff.totpSecretEnc ?? '', 'base64')).toString()).toBe(
      totpSecret,
    );

    const second = await rotation.rotate();
    expect(second.files.rotated).toBe(0);
    expect(second.totpSecrets.rotated).toBe(0);
  });

  it('après la rotation, la nouvelle clé seule suffit', async () => {
    after = await app(dir, NEW_KEY);
    const read = await after.app.get(MediaService).read(fileKey);
    expect(read.buffer.equals(PDF)).toBe(true);
  });

  it('laisse intact et signale un fichier illisible avec les deux clés', async () => {
    const stranger = encrypt(randomBytes(32), PDF);
    const key = `kyc-document/inconnu/${randomBytes(8).toString('hex')}`;
    await new LocalFsStorage(dir).put(key, stranger);
    await during.prisma.mediaFile.create({
      data: {
        ownerId,
        kind: 'KYC_DOCUMENT',
        storageKey: key,
        mimeType: 'application/pdf',
        sizeBytes: PDF.length,
        encrypted: true,
      },
    });
    const env = during.app.get<Env>(ENV);
    const report = await new KeyRotationService(
      during.prisma,
      new LocalFsStorage(dir),
      env,
    ).rotate();
    expect(report.files.failed).toContain(key);
    expect((await new LocalFsStorage(dir).get(key)).equals(stranger)).toBe(true);
  });

  it('refuse de démarrer avec la même clé en actuelle et en ancienne', async () => {
    await expect(app(dir, NEW_KEY, NEW_KEY)).rejects.toThrow(/STORAGE_ENCRYPTION_KEY_PREVIOUS/);
  });
});
