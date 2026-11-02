import { Module } from '@nestjs/common';
import { GeoModule } from '../geo/geo.module.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { OrderTransitionsService } from './order-transitions.service.js';
import {
  AdminOrdersController,
  OrdersController,
  PublicTrackingController,
  RecipientsController,
} from './orders.controller.js';
import { OrdersService } from './orders.service.js';

@Module({
  imports: [GeoModule, PricingModule],
  controllers: [
    OrdersController,
    RecipientsController,
    PublicTrackingController,
    AdminOrdersController,
  ],
  providers: [OrdersService, OrderTransitionsService],
  exports: [OrdersService, OrderTransitionsService],
})
export class OrdersModule {}
