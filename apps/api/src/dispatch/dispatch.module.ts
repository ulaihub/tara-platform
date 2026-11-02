import { Module } from '@nestjs/common';
import { OrdersModule } from '../orders/orders.module.js';
import { DispatchService } from './dispatch.service.js';
import { PresenceService } from './presence.service.js';
import { RiderLocationService } from './rider-location.service.js';

@Module({
  imports: [OrdersModule],
  providers: [PresenceService, DispatchService, RiderLocationService],
  exports: [PresenceService, DispatchService, RiderLocationService],
})
export class DispatchModule {}
