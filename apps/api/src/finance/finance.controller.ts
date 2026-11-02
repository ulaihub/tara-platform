import {
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { IdempotencyHeader, requiredIdempotencyKey } from '../common/idempotency.js';
import { pageOf, pageSchema } from '../common/pagination.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import type { Payment, Payout } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  CollectBody,
  CollectionDto,
  CreditBody,
  DepositBody,
  FinanceOverviewDto,
  MobileMoneyPayer,
  OfficeDepositBody,
  PaymentDto,
  PayoutBody,
  PayoutDto,
  PayoutListQuery,
  RejectPayoutBody,
  RiderHistoryQuery,
  RiderWalletDto,
  TopUpBody,
  WalletDto,
  WalletHistoryQuery,
  WalletLineDto,
} from './finance.schemas.js';
import {
  customerWallet,
  merchantPayable,
  PLATFORM_ACCOUNTS,
  riderCashHeld,
  riderPayable,
} from './ledger.accounts.js';
import { LedgerService } from './ledger.service.js';
import { OrderFinanceService } from './order-finance.service.js';
import { PayoutsService } from './payouts.service.js';
import { WalletsService } from './wallets.service.js';

type Out<T extends z.ZodType> = Promise<z.output<T>>;

const MONEY_HEADER = IdempotencyHeader(
  true,
  'Identifiant unique de l’opération (UUID). Renvoyer la même requête après une coupure réseau ne refait pas l’opération.',
);

export function toPaymentDto(payment: Payment): z.output<typeof PaymentDto> {
  return {
    id: payment.id,
    purpose: payment.purpose,
    status: payment.status,
    amount: payment.amount,
    orderId: payment.orderId,
    failureReason: payment.failureReason,
    createdAt: payment.createdAt.toISOString(),
    confirmedAt: payment.confirmedAt?.toISOString() ?? null,
  };
}

export function toPayoutDto(payout: Payout): z.output<typeof PayoutDto> {
  return {
    id: payout.id,
    beneficiary: payout.beneficiary,
    amount: payout.amount,
    fee: payout.fee,
    phone: payout.phone,
    status: payout.status,
    failureReason: payout.failureReason,
    requestedAt: payout.requestedAt.toISOString(),
    completedAt: payout.completedAt?.toISOString() ?? null,
  };
}

/** Solde Tara, portefeuille marchand et reversements (G1, G2, G3, G8). */
@ApiTags('Portefeuille')
@ApiBearerAuth()
@Controller()
export class WalletController {
  constructor(
    private readonly wallets: WalletsService,
    private readonly payouts: PayoutsService,
    private readonly finance: OrderFinanceService,
    private readonly prisma: PrismaService,
  ) {}

  @Get('me/wallet')
  @ApiZodResponse(WalletDto)
  wallet(@CurrentUser() user: AuthUser): Out<typeof WalletDto> {
    return this.wallets.overview(user.id);
  }

  /** Historique ligne par ligne : encaissements, frais déduits, reversements (G2). */
  @Get('me/wallet/transactions')
  @ApiZodQuery(WalletHistoryQuery)
  @ApiZodResponse(pageSchema(WalletLineDto))
  async transactions(
    @CurrentUser() user: AuthUser,
    @ValidQuery(WalletHistoryQuery) query: z.output<typeof WalletHistoryQuery>,
  ): Promise<{ items: z.output<typeof WalletLineDto>[]; nextCursor: string | null }> {
    if (query.account === 'customer') return this.wallets.history(customerWallet(user.id), query);
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId: user.id } });
    if (!merchant) throw AppError.notFound();
    return this.wallets.history(merchantPayable(merchant.id), query);
  }

  /** Recharge du solde par Mobile Money : demande envoyée au téléphone du payeur. */
  @Post('me/wallet/topup')
  @MONEY_HEADER
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiZodBody(TopUpBody)
  @ApiZodResponse(PaymentDto, HttpStatus.CREATED)
  async topUp(
    @CurrentUser() user: AuthUser,
    @ValidBody(TopUpBody) body: z.output<typeof TopUpBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Out<typeof PaymentDto> {
    const payment = await this.wallets.topUp(
      user.id,
      body.amount,
      body.phone,
      body.operator,
      requiredIdempotencyKey(key),
    );
    return toPaymentDto(payment);
  }

  /** Remboursement du solde client vers Mobile Money (G8). */
  @Post('me/wallet/refund')
  @MONEY_HEADER
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiZodBody(PayoutBody)
  @ApiZodResponse(PayoutDto, HttpStatus.CREATED)
  async refund(
    @CurrentUser() user: AuthUser,
    @ValidBody(PayoutBody) body: z.output<typeof PayoutBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Out<typeof PayoutDto> {
    const payout = await this.payouts.request({
      beneficiary: 'CUSTOMER',
      ownerId: user.id,
      amount: body.amount,
      phone: body.phone,
      operator: body.operator,
      idempotencyKey: `customer:${user.id}:${requiredIdempotencyKey(key)}`,
    });
    return toPayoutDto(payout);
  }

  /** Reversement à la demande du portefeuille marchand, réservé aux offres Pro et Business (G3). */
  @Post('me/merchant/payouts')
  @MONEY_HEADER
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiZodResponse(PayoutDto, HttpStatus.CREATED)
  async merchantPayout(
    @CurrentUser() user: AuthUser,
    @Headers('idempotency-key') key: string | undefined,
  ): Out<typeof PayoutDto> {
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId: user.id } });
    if (!merchant) throw AppError.notFound();
    if (merchant.plan === 'FREE') throw AppError.forbidden('PAYOUT_NOT_ALLOWED');
    const payout = await this.payouts.request({
      beneficiary: 'MERCHANT',
      ownerId: merchant.id,
      phone: merchant.payoutPhone,
      operator: merchant.payoutOperator,
      idempotencyKey: `merchant:${merchant.id}:${requiredIdempotencyKey(key)}`,
    });
    return toPayoutDto(payout);
  }

  @Get('me/payouts')
  @ApiZodQuery(PayoutListQuery)
  @ApiZodResponse(pageSchema(PayoutDto))
  async myPayouts(
    @CurrentUser() user: AuthUser,
    @ValidQuery(PayoutListQuery) query: z.output<typeof PayoutListQuery>,
  ): Promise<{ items: z.output<typeof PayoutDto>[]; nextCursor: string | null }> {
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId: user.id } });
    const rows = await this.prisma.payout.findMany({
      where: {
        OR: [{ userId: user.id }, ...(merchant ? [{ merchantId: merchant.id }] : [])],
        ...(query.status ? { status: query.status } : {}),
        ...(query.cursor ? { id: { lt: query.cursor } } : {}),
      },
      orderBy: { id: 'desc' },
      take: query.limit + 1,
    });
    const page = pageOf(rows, query.limit);
    return { items: page.items.map(toPayoutDto), nextCursor: page.nextCursor };
  }

  /** Paiement d'avance des frais d'une commande par Mobile Money (G1). */
  @Post('orders/:id/pay')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiTags('Commandes')
  @ApiZodBody(MobileMoneyPayer)
  @ApiZodResponse(PaymentDto, HttpStatus.CREATED)
  async payOrder(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(MobileMoneyPayer) body: z.output<typeof MobileMoneyPayer>,
  ): Out<typeof PaymentDto> {
    return toPaymentDto(await this.finance.pay(user.id, id, body.phone));
  }

  /** Statut d'un paiement (à interroger si la connexion temps réel est coupée). */
  @Get('payments/:id')
  @ApiZodResponse(PaymentDto)
  async payment(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Out<typeof PaymentDto> {
    const payment = await this.prisma.payment.findUnique({
      where: { id },
      include: { rider: { select: { userId: true } } },
    });
    if (!payment || (payment.payerId !== user.id && payment.rider?.userId !== user.id)) {
      throw AppError.notFound('PAYMENT_NOT_FOUND');
    }
    return toPaymentDto(payment);
  }
}

/** Argent du livreur : gains, espèces, retraits, dépôts, encaissement à la porte (E5, G4, G5). */
@ApiTags('Livreur')
@ApiBearerAuth()
@Roles('RIDER')
@Controller('rider')
export class RiderFinanceController {
  constructor(
    private readonly wallets: WalletsService,
    private readonly payouts: PayoutsService,
    private readonly finance: OrderFinanceService,
    private readonly prisma: PrismaService,
  ) {}

  private async riderId(userId: string): Promise<string> {
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId } });
    if (!rider) throw AppError.forbidden();
    return rider.id;
  }

  @Get('wallet')
  @ApiZodResponse(RiderWalletDto)
  wallet(@CurrentUser() user: AuthUser): Out<typeof RiderWalletDto> {
    return this.wallets.riderOverview(user.id);
  }

  @Get('wallet/transactions')
  @ApiZodQuery(RiderHistoryQuery)
  @ApiZodResponse(pageSchema(WalletLineDto))
  async transactions(
    @CurrentUser() user: AuthUser,
    @ValidQuery(RiderHistoryQuery) query: z.output<typeof RiderHistoryQuery>,
  ): Promise<{ items: z.output<typeof WalletLineDto>[]; nextCursor: string | null }> {
    const riderId = await this.riderId(user.id);
    return this.wallets.history(
      query.account === 'cash' ? riderCashHeld(riderId) : riderPayable(riderId),
      query,
    );
  }

  /** Retrait des gains vers Mobile Money (gains moins espèces détenues). */
  @Post('withdrawals')
  @MONEY_HEADER
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiZodBody(PayoutBody)
  @ApiZodResponse(PayoutDto, HttpStatus.CREATED)
  async withdraw(
    @CurrentUser() user: AuthUser,
    @ValidBody(PayoutBody) body: z.output<typeof PayoutBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Out<typeof PayoutDto> {
    const riderId = await this.riderId(user.id);
    const payout = await this.payouts.request({
      beneficiary: 'RIDER',
      ownerId: riderId,
      amount: body.amount,
      phone: body.phone,
      operator: body.operator,
      idempotencyKey: `rider:${riderId}:${requiredIdempotencyKey(key)}`,
    });
    return toPayoutDto(payout);
  }

  /** Dépôt des espèces détenues par Mobile Money (G5). */
  @Post('cash-deposits')
  @MONEY_HEADER
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiZodBody(DepositBody)
  @ApiZodResponse(PaymentDto, HttpStatus.CREATED)
  async deposit(
    @CurrentUser() user: AuthUser,
    @ValidBody(DepositBody) body: z.output<typeof DepositBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Out<typeof PaymentDto> {
    const payment = await this.wallets.depositByMobileMoney(
      user.id,
      body.amount,
      body.phone,
      body.operator,
      requiredIdempotencyKey(key),
    );
    return toPaymentDto(payment);
  }

  /** Ce qu'il reste à encaisser auprès du destinataire. */
  @Get('orders/:id/collection')
  @ApiZodResponse(CollectionDto)
  async collection(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Out<typeof CollectionDto> {
    const riderId = await this.riderId(user.id);
    const order = await this.prisma.order.findUnique({ where: { id } });
    if (order?.riderId !== riderId) throw AppError.notFound('ORDER_NOT_FOUND');
    return this.finance.collectionState(order);
  }

  /**
   * Encaissement à la porte (E5) : espèces, ou demande Mobile Money envoyée au téléphone du
   * destinataire et confirmée automatiquement (événement `payment.status`).
   */
  @Post('orders/:id/collect')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(CollectBody)
  @ApiZodResponse(CollectionDto)
  collect(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(CollectBody) body: z.output<typeof CollectBody>,
  ): Out<typeof CollectionDto> {
    return this.finance.collect(
      user.id,
      id,
      body.method === 'CASH'
        ? { kind: 'CASH' }
        : { kind: 'MOBILE_MONEY', phone: body.phone, operator: body.operator },
    );
  }
}

/** Back-office finance (H5) : soldes, validation des reversements, dépôts au bureau, avoirs. */
@ApiTags('Back-office · finance')
@ApiBearerAuth()
@Roles('ADMIN', 'FINANCE')
@Controller('admin/finance')
export class AdminFinanceController {
  constructor(
    private readonly wallets: WalletsService,
    private readonly payouts: PayoutsService,
    private readonly ledger: LedgerService,
    private readonly prisma: PrismaService,
  ) {}

  @Get('overview')
  @ApiZodResponse(FinanceOverviewDto)
  async overview(): Out<typeof FinanceOverviewDto> {
    const accounts = Object.values(PLATFORM_ACCOUNTS);
    const balances = await this.ledger.balances(accounts);
    return {
      currency: 'XAF',
      accounts: accounts.map((account) => ({
        code: account.code,
        name: account.name,
        balance: balances.get(account.code) ?? 0,
      })),
      payoutsAwaitingApproval: await this.prisma.payout.count({
        where: { status: 'AWAITING_APPROVAL' },
      }),
      paymentsPending: await this.prisma.payment.count({ where: { status: 'PENDING' } }),
    };
  }

  @Get('payouts')
  @ApiZodQuery(PayoutListQuery)
  @ApiZodResponse(pageSchema(PayoutDto))
  async list(
    @ValidQuery(PayoutListQuery) query: z.output<typeof PayoutListQuery>,
  ): Promise<{ items: z.output<typeof PayoutDto>[]; nextCursor: string | null }> {
    const rows = await this.prisma.payout.findMany({
      where: {
        ...(query.status ? { status: query.status } : {}),
        ...(query.cursor ? { id: { lt: query.cursor } } : {}),
      },
      orderBy: { id: 'desc' },
      take: query.limit + 1,
    });
    const page = pageOf(rows, query.limit);
    return { items: page.items.map(toPayoutDto), nextCursor: page.nextCursor };
  }

  @Post('payouts/:id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(PayoutDto)
  async approve(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() request: Request,
  ): Out<typeof PayoutDto> {
    return toPayoutDto(await this.payouts.approve(id, user, request));
  }

  @Post('payouts/:id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(RejectPayoutBody)
  @ApiZodResponse(PayoutDto)
  async reject(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(RejectPayoutBody) body: z.output<typeof RejectPayoutBody>,
    @Req() request: Request,
  ): Out<typeof PayoutDto> {
    return toPayoutDto(await this.payouts.reject(id, user, body.reason, request));
  }

  /** Espèces remises au bureau par un livreur (G5). */
  @Post('riders/:riderId/cash-deposits')
  @MONEY_HEADER
  @ApiZodBody(OfficeDepositBody)
  @ApiZodResponse(z.object({ entryId: z.uuid(), cashHeld: z.int() }), HttpStatus.CREATED)
  depositAtOffice(
    @CurrentUser() user: AuthUser,
    @Param('riderId', ParseUUIDPipe) riderId: string,
    @ValidBody(OfficeDepositBody) body: z.output<typeof OfficeDepositBody>,
    @Headers('idempotency-key') key: string | undefined,
    @Req() request: Request,
  ): Promise<{ entryId: string; cashHeld: number }> {
    return this.wallets.depositAtOffice(
      user,
      riderId,
      body.amount,
      body.note,
      requiredIdempotencyKey(key),
      request,
    );
  }

  /** Avoir crédité sur le solde d'un client ou d'un marchand (G8). */
  @Post('users/:userId/credits')
  @MONEY_HEADER
  @ApiZodBody(CreditBody)
  @ApiZodResponse(z.object({ entryId: z.uuid(), balance: z.int() }), HttpStatus.CREATED)
  credit(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
    @ValidBody(CreditBody) body: z.output<typeof CreditBody>,
    @Headers('idempotency-key') key: string | undefined,
    @Req() request: Request,
  ): Promise<{ entryId: string; balance: number }> {
    return this.wallets.grantCredit(
      user,
      userId,
      body.amount,
      body.reason,
      requiredIdempotencyKey(key),
      request,
    );
  }
}
