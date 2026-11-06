import { Module } from '@nestjs/common';
import { DispatchModule } from '../dispatch/dispatch.module.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { RiderAppModule } from '../rider-app/rider-app.module.js';
import { RoadService } from '../routing/road.service.js';
import { TrackingModule } from '../tracking/tracking.module.js';
import { LiveMapService } from './live-map.service.js';
import { OpsController } from './ops.controller.js';
import { RiderTrailService } from './rider-trail.service.js';

/** Back-office d'exploitation : carte en direct et alertes (H1). */
@Module({
  imports: [DispatchModule, PricingModule, RiderAppModule, TrackingModule],
  controllers: [OpsController],
  providers: [LiveMapService, RiderTrailService, RoadService],
})
export class OpsModule {}
