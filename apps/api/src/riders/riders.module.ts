import { Module } from '@nestjs/common';
import { KycExpiryService } from './kyc-expiry.service.js';
import { AdminRidersController, RidersController } from './riders.controller.js';
import { RidersService } from './riders.service.js';

@Module({
  controllers: [RidersController, AdminRidersController],
  providers: [RidersService, KycExpiryService],
  exports: [RidersService],
})
export class RidersModule {}
