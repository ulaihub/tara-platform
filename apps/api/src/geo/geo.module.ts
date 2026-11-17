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

@Module({
  controllers: [
    AddressesController,
    LocationLinksController,
    PublicLocationLinksController,
    AdminZonesController,
  ],
  providers: [ZonesRepository, AddressesService, LocationLinksService],
  exports: [ZonesRepository, AddressesService, LocationLinksService],
})
export class GeoModule {}
