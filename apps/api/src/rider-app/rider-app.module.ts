import { Module } from '@nestjs/common';
import { DispatchModule } from '../dispatch/dispatch.module.js';
import { FinanceModule } from '../finance/finance.module.js';
import { GeoModule } from '../geo/geo.module.js';
import { OrdersModule } from '../orders/orders.module.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { RealtimeGateway } from '../realtime/realtime.gateway.js';
import { OrderSupportService } from './order-support.service.js';
import {
  AdminDispatchController,
  AdminSupportController,
  RiderAppController,
  SenderDecisionsController,
} from './rider-app.controller.js';
import { RiderOrdersService } from './rider-orders.service.js';
import { SafetyAlertsService } from './safety-alerts.service.js';

@Module({
  imports: [DispatchModule, OrdersModule, GeoModule, FinanceModule, PricingModule],
  controllers: [
    RiderAppController,
    SenderDecisionsController,
    AdminDispatchController,
    AdminSupportController,
  ],
  providers: [RiderOrdersService, OrderSupportService, SafetyAlertsService, RealtimeGateway],
})
export class RiderAppModule {}
