import { Module } from '@nestjs/common';
import { OrdersModule } from '../orders/orders.module.js';
import {
  AdminFinanceController,
  RiderFinanceController,
  WalletController,
} from './finance.controller.js';
import { CashDisciplineService } from './cash-discipline.service.js';
import { RiderBalanceService } from './rider-balance.service.js';
import { JournalExportService } from './journal-export.service.js';
import { OrderFinanceService } from './order-finance.service.js';
import { PayoutsService } from './payouts.service.js';
import { ReconciliationService } from './reconciliation.service.js';
import { StatementsService } from './statements.service.js';
import { WalletsService } from './wallets.service.js';

@Module({
  imports: [OrdersModule],
  controllers: [WalletController, RiderFinanceController, AdminFinanceController],
  providers: [
    OrderFinanceService,
    PayoutsService,
    WalletsService,
    ReconciliationService,
    JournalExportService,
    StatementsService,
    CashDisciplineService,
    RiderBalanceService,
  ],
  exports: [
    OrderFinanceService,
    PayoutsService,
    WalletsService,
    ReconciliationService,
    CashDisciplineService,
    RiderBalanceService,
  ],
})
export class FinanceModule {}
