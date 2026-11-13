import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import type { z } from 'zod';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { AppError } from '../common/errors/app-error.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { MediaService } from '../storage/media.service.js';
import { type ParcelAnalysisDto, toAnalysisDto } from './parcel-analysis.schemas.js';
import {
  PARCEL_VISION,
  type ParcelVerdict,
  type ParcelVision,
  ParcelVisionUnavailableError,
} from './parcel-vision.js';

/**
 * Photo du colis analysée à la commande : taille, nature, fragilité et objets interdits
 * proposés à l'expéditeur, qui confirme ou corrige. Une seule analyse par photo (gardée),
 * un nombre d'analyses limité par heure et par compte (coût du modèle).
 */
@Injectable()
export class ParcelAnalysisService {
  private readonly logger = new Logger(ParcelAnalysisService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    @Inject(PARCEL_VISION) private readonly vision: ParcelVision | null,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async analyze(userId: string, photoKey: string): Promise<z.output<typeof ParcelAnalysisDto>> {
    if (!this.vision) throw this.unavailable();
    await this.media.assertOwned(userId, photoKey, ['PARCEL_PHOTO']);
    const known = await this.prisma.parcelAnalysis.findUnique({ where: { photoKey } });
    if (known) return toAnalysisDto(photoKey, known.result as ParcelVerdict);

    const recent = await this.prisma.parcelAnalysis.count({
      where: { ownerId: userId, createdAt: { gte: new Date(Date.now() - 3_600_000) } },
    });
    if (recent >= this.env.PARCEL_ANALYSIS_PER_HOUR) {
      throw AppError.tooMany('PARCEL_ANALYSIS_LIMIT');
    }

    const image = await this.media.read(photoKey);
    let verdict: ParcelVerdict;
    try {
      verdict = await this.vision.analyze(image);
    } catch (error) {
      if (error instanceof ParcelVisionUnavailableError) {
        this.logger.warn(`Analyse de colis impossible : ${error.message}`);
        throw this.unavailable();
      }
      throw error;
    }
    try {
      await this.prisma.parcelAnalysis.create({
        data: {
          ownerId: userId,
          photoKey,
          engine: this.vision.engine,
          result: verdict as unknown as Prisma.InputJsonValue,
        },
      });
    } catch (error) {
      // Deux demandes simultanées pour la même photo : la première analyse fait foi.
      if (!(error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')) {
        throw error;
      }
    }
    return toAnalysisDto(photoKey, verdict);
  }

  private unavailable(): AppError {
    return new AppError('PARCEL_ANALYSIS_UNAVAILABLE', HttpStatus.SERVICE_UNAVAILABLE);
  }
}
