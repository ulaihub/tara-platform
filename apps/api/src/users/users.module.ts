import { Module } from '@nestjs/common';
import { MeController } from './me.controller.js';
import { PublicConfigController } from './public-config.controller.js';
import { UsersService } from './users.service.js';

@Module({
  controllers: [MeController, PublicConfigController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
