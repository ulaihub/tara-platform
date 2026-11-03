import { Module } from '@nestjs/common';
import { CourseTrackService } from './course-track.service.js';
import { AdminTrackController, RiderTrackController } from './tracking.controller.js';

/** Trajet des courses : enregistrement, alertes au support, conservation de 90 jours. */
@Module({
  controllers: [RiderTrackController, AdminTrackController],
  providers: [CourseTrackService],
  exports: [CourseTrackService],
})
export class TrackingModule {}
