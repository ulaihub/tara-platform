import { Module } from '@nestjs/common';
import { MetricsController } from './metrics.controller.js';
import { MetricsService } from './metrics.service.js';

/** Indicateurs du back-office (H7). */
@Module({ controllers: [MetricsController], providers: [MetricsService] })
export class MetricsModule {}
