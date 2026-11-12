import { Module } from '@nestjs/common';
import { GeoModule } from '../geo/geo.module.js';
import { DistanceService } from '../routing/distance.service.js';
import { AdminPricingController, QuoteController } from './pricing.controller.js';
import { PricingSettingsService } from './pricing-settings.service.js';
import { PricingService } from './pricing.service.js';
import { PromoService } from './promo.service.js';

@Module({
  imports: [GeoModule],
  controllers: [QuoteController, AdminPricingController],
  providers: [DistanceService, PricingService, PricingSettingsService, PromoService],
  exports: [PricingService, PricingSettingsService, PromoService, DistanceService],
})
export class PricingModule {}
