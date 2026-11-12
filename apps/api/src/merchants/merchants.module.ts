import { Module } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { AdminMerchantsController } from './admin-merchants.controller.js';
import { AdminMerchantsService } from './admin-merchants.service.js';

/** Boutiques vues par l'équipe (H4). */
@Module({
  imports: [PaymentsModule, PricingModule],
  controllers: [AdminMerchantsController],
  providers: [AdminMerchantsService],
})
export class MerchantsModule {}
