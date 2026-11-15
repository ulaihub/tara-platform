import { Module } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module.js';
import { AdminPrivacyController, PrivacyController } from './privacy.controller.js';
import { PrivacyService } from './privacy.service.js';
import { RetentionService } from './retention.service.js';

@Module({
  imports: [PaymentsModule],
  controllers: [PrivacyController, AdminPrivacyController],
  providers: [PrivacyService, RetentionService],
})
export class PrivacyModule {}
