import { Module } from '@nestjs/common';
import { OrdersModule } from '../orders/orders.module.js';
import {
  AdminFinanceController,
  RiderFinanceController,
  WalletController,
} from './finance.controller.js';
import { OrderFinanceService } from './order-finance.service.js';
import { PayoutsService } from './payouts.service.js';
import { WalletsService } from './wallets.service.js';

@Module({
  imports: [OrdersModule],
  controllers: [WalletController, RiderFinanceController, AdminFinanceController],
  providers: [OrderFinanceService, PayoutsService, WalletsService],
  exports: [OrderFinanceService, PayoutsService, WalletsService],
})
export class FinanceModule {}
