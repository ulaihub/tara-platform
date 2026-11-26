import { Module } from '@nestjs/common';
import { AddressesService } from './addresses.service.js';
import {
  AddressesController,
  AdminZonesController,
  LocationLinksController,
  PublicLocationLinksController,
} from './geo.controller.js';
import { LocationLinksService } from './location-links.service.js';
import { ZonesRepository } from './zones.repository.js';

import { AdminLandmarksController, LandmarksController } from './landmarks.controller.js';
@Module({
  controllers: [
    AddressesController,
    LandmarksController,
    AdminLandmarksController,
    LocationLinksController,
    PublicLocationLinksController,
    AdminZonesController,
  ],
  providers: [ZonesRepository, AddressesService, LocationLinksService],
  exports: [ZonesRepository, AddressesService, LocationLinksService],
})
export class GeoModule {}
