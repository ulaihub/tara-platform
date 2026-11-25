import { Module } from '@nestjs/common';
import { FinanceModule } from '../finance/finance.module.js';
import { OrdersModule } from '../orders/orders.module.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { TrackingModule } from '../tracking/tracking.module.js';
import { DispatchService } from './dispatch.service.js';
import { OnlineTimeService } from './online-time.service.js';
import { PresenceService } from './presence.service.js';
import { RiderLocationService } from './rider-location.service.js';
import { SilentRiderService } from './silent-rider.service.js';

@Module({
  imports: [OrdersModule, PricingModule, TrackingModule, FinanceModule],
  providers: [
    PresenceService,
    DispatchService,
    RiderLocationService,
    OnlineTimeService,
    SilentRiderService,
  ],
  exports: [
    PresenceService,
    DispatchService,
    RiderLocationService,
    OnlineTimeService,
    SilentRiderService,
  ],
})
export class DispatchModule {}
