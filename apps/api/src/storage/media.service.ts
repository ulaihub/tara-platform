import { randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { decrypt, encrypt } from '../common/crypto.js';
import type { MediaKind } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from './object-storage.js';

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

interface MediaRule {
  maxBytes: number;
  mimeTypes: string[];
  encrypted: boolean;
}

/** Règles par type de fichier. Les photos sont compressées par l'app (< 150 Ko visés). */
export const MEDIA_RULES: Record<MediaKind, MediaRule> = {
  ADDRESS_PHOTO: { maxBytes: 1_000_000, mimeTypes: IMAGE_TYPES, encrypted: false },
  PROOF_PHOTO: { maxBytes: 1_000_000, mimeTypes: IMAGE_TYPES, encrypted: false },
  VOICE_NOTE: {
    maxBytes: 1_000_000,
    mimeTypes: [
      'audio/aac',
      'audio/mp4',
      'audio/x-m4a',
      'audio/mpeg',
      'audio/ogg',
      'audio/webm',
      'audio/3gpp',
      'audio/amr',
    ],
    encrypted: false,
  },
  KYC_DOCUMENT: {
    maxBytes: 5_000_000,
    mimeTypes: [...IMAGE_TYPES, 'application/pdf'],
    encrypted: true,
  },
};

/** Type réel d'un fichier image ou PDF, d'après ses premiers octets. */
export function sniffMimeType(data: Buffer): string | null {
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) {
    return 'image/jpeg';
  }
  if (data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'image/png';
  }
  if (
    data.subarray(0, 4).toString('latin1') === 'RIFF' &&
    data.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'image/webp';
  }
  if (data.subarray(0, 5).toString('latin1') === '%PDF-') return 'application/pdf';
  return null;
}

export interface UploadedMedia {
  buffer: Buffer;
  mimetype: string;
  size: number;
}

export interface StoredMedia {
  id: string;
  key: string;
  kind: MediaKind;
  mimeType: string;
  sizeBytes: number;
}

@Injectable()
export class MediaService {
  private readonly encryptionKey: Buffer;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(ENV) env: Env,
  ) {
    this.encryptionKey = Buffer.from(env.STORAGE_ENCRYPTION_KEY, 'base64');
  }

  async store(ownerId: string, kind: MediaKind, file: UploadedMedia): Promise<StoredMedia> {
    const rule = MEDIA_RULES[kind];
    if (file.size > rule.maxBytes) {
      throw AppError.badRequest('MEDIA_TOO_LARGE', { maxKb: Math.floor(rule.maxBytes / 1000) });
    }
    // Pour les images et les PDF, le type déclaré par le client doit correspondre au contenu.
    const sniffed = sniffMimeType(file.buffer);
    const declared = file.mimetype.toLowerCase();
    const mimeType = declared.startsWith('audio/') ? declared : sniffed;
    if (!mimeType || !rule.mimeTypes.includes(mimeType)) {
      throw AppError.badRequest('MEDIA_TYPE_NOT_ALLOWED');
    }

    const now = new Date();
    const key = `${kind.toLowerCase().replace('_', '-')}/${now.getUTCFullYear()}/${String(
      now.getUTCMonth() + 1,
    ).padStart(2, '0')}/${randomUUID()}`;
    const body = rule.encrypted ? encrypt(this.encryptionKey, file.buffer) : file.buffer;
    await this.storage.put(key, body);

    const media = await this.prisma.mediaFile.create({
      data: {
        ownerId,
        kind,
        storageKey: key,
        mimeType,
        sizeBytes: file.size,
        encrypted: rule.encrypted,
      },
    });
    return { id: media.id, key, kind, mimeType, sizeBytes: file.size };
  }

  /** Vérifie qu'un fichier existe, est du bon type et appartient bien à l'utilisateur. */
  async assertOwned(ownerId: string, key: string, kinds: MediaKind[]): Promise<void> {
    const media = await this.prisma.mediaFile.findUnique({ where: { storageKey: key } });
    if (!media || media.ownerId !== ownerId || !kinds.includes(media.kind)) {
      throw AppError.unprocessable('MEDIA_NOT_FOUND');
    }
  }

  /** Contenu en clair d'un fichier (déchiffré si nécessaire). */
  async read(key: string): Promise<{ buffer: Buffer; mimeType: string }> {
    const media = await this.prisma.mediaFile.findUnique({ where: { storageKey: key } });
    if (!media) throw AppError.notFound('MEDIA_NOT_FOUND');
    const stored = await this.storage.get(key);
    return {
      buffer: media.encrypted ? decrypt(this.encryptionKey, stored) : stored,
      mimeType: media.mimeType,
    };
  }
}
