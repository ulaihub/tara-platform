import { Module } from '@nestjs/common';
import { OrdersModule } from '../orders/orders.module.js';
import { TrackingModule } from '../tracking/tracking.module.js';
import { DispatchService } from './dispatch.service.js';
import { OnlineTimeService } from './online-time.service.js';
import { PresenceService } from './presence.service.js';
import { RiderLocationService } from './rider-location.service.js';

@Module({
  imports: [OrdersModule, TrackingModule],
  providers: [PresenceService, DispatchService, RiderLocationService, OnlineTimeService],
  exports: [PresenceService, DispatchService, RiderLocationService, OnlineTimeService],
})
export class DispatchModule {}
