/**
 * Rotation de la clé de chiffrement du stockage (procédure : docs/SECURITE.md).
 *
 *   STORAGE_ENCRYPTION_KEY=<nouvelle> STORAGE_ENCRYPTION_KEY_PREVIOUS=<ancienne> \
 *     node dist/storage/rotate-key.js
 *
 * Code de sortie 1 si des éléments sont restés illisibles : ne pas retirer l'ancienne clé.
 */
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { ConfigModule } from '../config/config.module.js';
import { PrismaModule } from '../prisma/prisma.module.js';
import { KeyRotationService } from './key-rotation.service.js';
import { StorageModule } from './storage.module.js';

@Module({ imports: [ConfigModule, PrismaModule, StorageModule], providers: [KeyRotationService] })
class KeyRotationModule {}

const log = (line: string) => process.stdout.write(`${line}\n`);
const app = await NestFactory.createApplicationContext(KeyRotationModule, {
  logger: ['error', 'warn'],
});
try {
  const report = await app.get(KeyRotationService).rotate(log);
  const failed = [...report.files.failed, ...report.totpSecrets.failed];
  if (failed.length > 0) {
    log(`Illisibles avec les deux clés : ${failed.join(', ')}`);
    log("Garder STORAGE_ENCRYPTION_KEY_PREVIOUS tant que ces éléments n'ont pas été examinés.");
    process.exitCode = 1;
  } else {
    log('Rotation terminée : STORAGE_ENCRYPTION_KEY_PREVIOUS peut être retirée.');
  }
} finally {
  await app.close();
}
