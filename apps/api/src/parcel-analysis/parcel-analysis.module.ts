import { Module } from '@nestjs/common';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { ParcelAnalysisController } from './parcel-analysis.controller.js';
import { ParcelAnalysisService } from './parcel-analysis.service.js';
import {
  ClaudeParcelVision,
  FakeParcelVision,
  PARCEL_VISION,
  type ParcelVision,
} from './parcel-vision.js';

@Module({
  controllers: [ParcelAnalysisController],
  providers: [
    {
      provide: PARCEL_VISION,
      inject: [ENV],
      useFactory: (env: Env): ParcelVision | null => {
        switch (env.PARCEL_VISION_PROVIDER) {
          case 'claude':
            return new ClaudeParcelVision({
              apiKey: env.ANTHROPIC_API_KEY ?? '',
              model: env.PARCEL_VISION_MODEL,
            });
          case 'fake':
            return new FakeParcelVision();
          case 'none':
            return null;
        }
      },
    },
    ParcelAnalysisService,
  ],
})
export class ParcelAnalysisModule {}
