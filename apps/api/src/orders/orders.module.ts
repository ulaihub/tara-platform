import { Module } from '@nestjs/common';
import { LegalModule } from '../legal/legal.module.js';
import { GeoModule } from '../geo/geo.module.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { OrderTransitionsService } from './order-transitions.service.js';
import {
  AdminOrdersController,
  OrdersController,
  RecipientsController,
} from './orders.controller.js';
import { OrdersService } from './orders.service.js';
import { PendingDeliveriesService } from './pending-deliveries.service.js';
import { RatingsService } from './ratings.service.js';

@Module({
  imports: [GeoModule, PricingModule, LegalModule],
  controllers: [OrdersController, RecipientsController, AdminOrdersController],
  providers: [OrdersService, OrderTransitionsService, RatingsService, PendingDeliveriesService],
  exports: [OrdersService, OrderTransitionsService, RatingsService],
})
export class OrdersModule {}
