import { Module } from '@nestjs/common';
import { FinanceModule } from '../finance/finance.module.js';
import { OrdersModule } from '../orders/orders.module.js';
import { AdminOfficeController, SenderOfficeController } from './office-returns.controller.js';
import { OfficeReturnsService } from './office-returns.service.js';

/** Retour sans dette : colis gardés au bureau Tara (paiement, remise, rappels). */
@Module({
  imports: [OrdersModule, FinanceModule],
  controllers: [SenderOfficeController, AdminOfficeController],
  providers: [OfficeReturnsService],
  exports: [OfficeReturnsService],
})
export class OfficeReturnsModule {}
