import { Module } from '@nestjs/common';
import { LegalModule } from '../legal/legal.module.js';
import { GeoModule } from '../geo/geo.module.js';
import { PresenceService } from '../dispatch/presence.service.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { MerchantActivityController, MerchantActivityService } from './merchant-activity.js';
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
  controllers: [
    OrdersController,
    RecipientsController,
    AdminOrdersController,
    MerchantActivityController,
  ],
  providers: [
    OrdersService,
    OrderTransitionsService,
    RatingsService,
    PendingDeliveriesService,
    PresenceService,
    MerchantActivityService,
  ],
  exports: [OrdersService, OrderTransitionsService, RatingsService],
})
export class OrdersModule {}
