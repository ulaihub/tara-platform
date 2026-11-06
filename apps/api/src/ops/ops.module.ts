import { Module } from '@nestjs/common';
import { DispatchModule } from '../dispatch/dispatch.module.js';
import { RiderAppModule } from '../rider-app/rider-app.module.js';
import { TrackingModule } from '../tracking/tracking.module.js';
import { LiveMapService } from './live-map.service.js';
import { OpsController } from './ops.controller.js';

/** Back-office d'exploitation : carte en direct et alertes (H1). */
@Module({
  imports: [DispatchModule, RiderAppModule, TrackingModule],
  controllers: [OpsController],
  providers: [LiveMapService],
})
export class OpsModule {}
