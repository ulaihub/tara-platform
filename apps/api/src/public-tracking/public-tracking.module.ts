import { Module } from '@nestjs/common';
import { DispatchModule } from '../dispatch/dispatch.module.js';
import { FinanceModule } from '../finance/finance.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { OrdersModule } from '../orders/orders.module.js';
import { PublicReceiptController } from './public-receipt.controller.js';
import { PublicReceiptService } from './public-receipt.service.js';
import { PublicTrackingController } from './public-tracking.controller.js';
import { PublicTrackingService } from './public-tracking.service.js';

/**
 * Pages publiques sans compte : suivi du destinataire (F2) et vérification d'un reçu.
 */
@Module({
  imports: [OrdersModule, DispatchModule, FinanceModule, NotificationsModule],
  controllers: [PublicTrackingController, PublicReceiptController],
  providers: [PublicTrackingService, PublicReceiptService],
})
export class PublicTrackingModule {}
