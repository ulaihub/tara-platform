import { Module } from '@nestjs/common';
import { DispatchModule } from '../dispatch/dispatch.module.js';
import { FinanceModule } from '../finance/finance.module.js';
import { OrdersModule } from '../orders/orders.module.js';
import { PublicTrackingController } from './public-tracking.controller.js';
import { PublicTrackingService } from './public-tracking.service.js';

/** Page de suivi publique du destinataire (F2) : commande, livreur, paiement à la porte. */
@Module({
  imports: [OrdersModule, DispatchModule, FinanceModule],
  controllers: [PublicTrackingController],
  providers: [PublicTrackingService],
})
export class PublicTrackingModule {}
