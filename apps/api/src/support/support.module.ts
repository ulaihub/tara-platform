import { Module } from '@nestjs/common';
import { AdminSupportController, SupportController } from './support.controller.js';
import { SupportService } from './support.service.js';

/** Service client (H6) : demandes depuis les apps et le back-office, preuves des litiges. */
@Module({
  controllers: [SupportController, AdminSupportController],
  providers: [SupportService],
})
export class SupportModule {}
