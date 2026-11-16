import {
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
  Req,
  Res,
  StreamableFile,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiProduces, ApiQuery, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { AuditService } from '../audit/audit.service.js';
import { cameroonDate } from '../common/time.js';
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
import type { Payment, Payout, Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  CollectBody,
  CollectionDto,
  CreditBody,
  DepositBody,
  FinanceOverviewDto,
  FreePayoutBody,
  FreePayoutDto,
  MobileMoneyPayer,
  OfficeDepositBody,
  TreasuryTransferBody,
  PaymentDto,
  PayoutBody,
  AdminPayoutDto,
  AdminPayoutListQuery,
  AdminPayoutPageDto,
  AdminPayoutViewEnum,
  PayoutDto,
  PayoutListQuery,
  RejectPayoutBody,
  RiderHistoryQuery,
  RiderTopUpBody,
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
import { JournalExportService } from './journal-export.service.js';
import { LedgerService } from './ledger.service.js';
import { OrderFinanceService } from './order-finance.service.js';
import { ReconciliationService } from './reconciliation.service.js';
import { StatementsService } from './statements.service.js';
import { PayoutsService } from './payouts.service.js';
import { OptionalPinProofBody } from '../pin/pin.schemas.js';
import { PinService } from '../pin/pin.service.js';
import { WalletsService } from './wallets.service.js';

type Out<T extends z.ZodType> = Promise<z.output<T>>;

const ReconciliationDto = z
  .object({
    day: z.iso.date(),
    status: z.enum(['BALANCED', 'DISCREPANCIES']),
    totals: z.record(z.string(), z.number()),
    discrepancies: z.array(
      z.object({
        type: z.string(),
        reference: z.string(),
        detail: z.string(),
        expected: z.number().optional(),
        actual: z.number().optional(),
      }),
    ),
    updatedAt: z.iso.datetime(),
  })
  .meta({ id: 'Reconciliation' });

function toReconciliationDto(report: {
  day: Date;
  status: 'BALANCED' | 'DISCREPANCIES';
  totals: unknown;
  discrepancies: unknown;
  updatedAt: Date;
}): z.output<typeof ReconciliationDto> {
  return {
    day: report.day.toISOString().slice(0, 10),
    status: report.status,
    totals: report.totals as Record<string, number>,
    discrepancies: report.discrepancies as z.output<typeof ReconciliationDto>['discrepancies'],
    updatedAt: report.updatedAt.toISOString(),
  };
}

const DayParam = z.iso.date();

/**
 * L'argent d'un client ou d'un livreur ne part que vers le numéro de son compte (vérifié par
 * code SMS) : un compte détourné ne peut pas être vidé vers un autre numéro.
 */
function assertOwnPhone(user: AuthUser, phone: string): void {
  if (phone !== user.phone) throw AppError.unprocessable('PAYOUT_PHONE_NOT_ALLOWED');
}

function pdfResponse(response: Response, file: { filename: string; pdf: Buffer }): StreamableFile {
  response.setHeader('Content-Type', 'application/pdf');
  response.setHeader('Content-Disposition', `attachment; filename="${file.filename}"`);
  return new StreamableFile(file.pdf);
}

const MONEY_HEADER = IdempotencyHeader(
  true,
  'Identifiant unique de l’opération (UUID). Renvoyer la même requête après une coupure réseau ne refait pas l’opération.',
);

export function toPaymentDto(payment: Payment): z.output<typeof PaymentDto> {
  return {
    mobileMoneyFee: payment.surcharge,
    total: payment.amount + payment.surcharge,
    id: payment.id,
    purpose: payment.purpose,
    status: payment.status,
    amount: payment.amount,
    orderId: payment.orderId,
    batchId: payment.batchId,
    failureReason: payment.failureReason,
    createdAt: payment.createdAt.toISOString(),
    confirmedAt: payment.confirmedAt?.toISOString() ?? null,
  };
}

export function toPayoutDto(payout: Payout): z.output<typeof PayoutDto> {
  return {
    withdrawalFee: payout.charge,
    received: payout.amount - payout.charge,
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

const PAYOUT_PEOPLE = {
  merchant: {
    select: { id: true, shopName: true, user: { select: { fullName: true, phone: true } } },
  },
  rider: { select: { id: true, user: { select: { fullName: true, phone: true } } } },
  user: { select: { id: true, fullName: true, phone: true } },
  approvedBy: { select: { fullName: true, phone: true } },
} as const satisfies Prisma.PayoutInclude;

/** Reversements d'une vue de la finance. */
function payoutView(view: z.output<typeof AdminPayoutViewEnum>): Prisma.PayoutWhereInput {
  switch (view) {
    case 'TO_APPROVE':
      return { status: 'AWAITING_APPROVAL' };
    case 'IN_PROGRESS':
      return { status: { in: ['PENDING', 'PROCESSING'] } };
    case 'FAILED':
      return { status: 'FAILED' };
    case 'SENT':
      return { status: 'SUCCEEDED' };
    case 'ALL':
      return {};
  }
}

function toAdminPayoutDto(
  payout: Prisma.PayoutGetPayload<{ include: typeof PAYOUT_PEOPLE }>,
): z.output<typeof AdminPayoutDto> {
  const owner = payout.merchant
    ? {
        id: payout.merchant.id,
        name: payout.merchant.user.fullName,
        phone: payout.merchant.user.phone,
        shopName: payout.merchant.shopName,
      }
    : payout.rider
      ? {
          id: payout.rider.id,
          name: payout.rider.user.fullName,
          phone: payout.rider.user.phone,
          shopName: null,
        }
      : payout.user
        ? {
            id: payout.user.id,
            name: payout.user.fullName,
            phone: payout.user.phone,
            shopName: null,
          }
        : null;
  return {
    ...toPayoutDto(payout),
    owner,
    approvedBy: payout.approvedBy ? (payout.approvedBy.fullName ?? payout.approvedBy.phone) : null,
    approvedAt: payout.approvedAt?.toISOString() ?? null,
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
    private readonly statements: StatementsService,
    private readonly pin: PinService,
  ) {}

  /** Relevé mensuel PDF du portefeuille marchand (G7), mois au format AAAA-MM. */
  @Get('me/merchant/statements/:month')
  @ApiProduces('application/pdf')
  @ApiOkResponse({ description: 'Relevé PDF', schema: { type: 'string', format: 'binary' } })
  async statement(
    @CurrentUser() user: AuthUser,
    @Param('month') month: string,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId: user.id } });
    if (!merchant) throw AppError.notFound();
    return pdfResponse(response, await this.statements.merchantStatement(merchant.id, month));
  }

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
    @Req() request: Request,
  ): Out<typeof PayoutDto> {
    assertOwnPhone(user, body.phone);
    await this.pin.assert(user, body, { request });
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

  /**
   * Reversement à la demande du portefeuille marchand, réservé aux offres Pro et Business (G3) ;
   * offre gratuite : seulement un petit solde, que le reversement de 18 h ne prendrait jamais.
   */
  @Post('me/merchant/payouts')
  @MONEY_HEADER
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiZodBody(OptionalPinProofBody)
  @ApiZodResponse(PayoutDto, HttpStatus.CREATED)
  async merchantPayout(
    @CurrentUser() user: AuthUser,
    @ValidBody(OptionalPinProofBody) body: z.output<typeof OptionalPinProofBody>,
    @Headers('idempotency-key') key: string | undefined,
    @Req() request: Request,
  ): Out<typeof PayoutDto> {
    const merchant = await this.prisma.merchantProfile.findUnique({ where: { userId: user.id } });
    if (!merchant) throw AppError.notFound();
    await this.pin.assert(user, body, { request });
    if (merchant.plan === 'FREE' && !(await this.payouts.smallBalance('MERCHANT', merchant.id))) {
      throw AppError.forbidden('PAYOUT_NOT_ALLOWED');
    }
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

  /** Paiement d'avance d'un lot de livraisons en une seule fois (C4, G1). */
  @Post('orders/batches/:id/pay')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiTags('Commandes')
  @ApiZodBody(MobileMoneyPayer)
  @ApiZodResponse(PaymentDto, HttpStatus.CREATED)
  async payBatch(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(MobileMoneyPayer) body: z.output<typeof MobileMoneyPayer>,
  ): Out<typeof PaymentDto> {
    return toPaymentDto(await this.finance.payBatch(user.id, id, body.phone));
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
    private readonly pin: PinService,
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
    @Req() request: Request,
  ): Out<typeof PayoutDto> {
    assertOwnPhone(user, body.phone);
    const rider = await this.prisma.riderProfile.findUnique({ where: { userId: user.id } });
    if (!rider) throw AppError.forbidden();
    // Livreur suspendu (colis disparu, fraude, espèces non versées) : son solde reste chez
    // Tara le temps de l'enquête, pour pouvoir dédommager l'expéditeur.
    if (rider.status === 'SUSPENDED') throw AppError.forbidden('PAYOUT_FROZEN');
    await this.pin.assert(user, body, { request });
    const riderId = rider.id;
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

  /**
   * Recharge du solde prépayé par Mobile Money (G5) : demande au téléphone du livreur,
   * confirmée par `payment.status`. Crédité du montant entier (frais payés par Tara).
   */
  @Post('topups')
  @MONEY_HEADER
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiZodBody(RiderTopUpBody)
  @ApiZodResponse(PaymentDto, HttpStatus.CREATED)
  async topUp(
    @CurrentUser() user: AuthUser,
    @ValidBody(RiderTopUpBody) body: z.output<typeof RiderTopUpBody>,
    @Headers('idempotency-key') key: string | undefined,
  ): Out<typeof PaymentDto> {
    const payment = await this.wallets.topUpRider(
      user.id,
      body.amount,
      body.phone,
      body.operator,
      requiredIdempotencyKey(key),
    );
    return toPaymentDto(payment);
  }

  /** Dépôt des espèces détenues par Mobile Money (G5, ancien fonctionnement). */
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
    private readonly reconciliation: ReconciliationService,
    private readonly journal: JournalExportService,
    private readonly statements: StatementsService,
    private readonly audit: AuditService,
  ) {}

  /** Rapprochements quotidiens, du plus récent au plus ancien (G6). */
  @Get('reconciliations')
  @ApiZodResponse(z.array(ReconciliationDto))
  async reconciliations(): Out<z.ZodArray<typeof ReconciliationDto>> {
    const reports = await this.prisma.reconciliationReport.findMany({
      orderBy: { day: 'desc' },
      take: 60,
    });
    return reports.map(toReconciliationDto);
  }

  /** Relance le rapprochement d'une journée (après correction d'un écart). */
  @Post('reconciliations/:day/run')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(ReconciliationDto)
  async runReconciliation(
    @CurrentUser() user: AuthUser,
    @Param('day') day: string,
  ): Out<typeof ReconciliationDto> {
    if (!DayParam.safeParse(day).success || day > cameroonDate(new Date())) {
      throw AppError.badRequest('VALIDATION_FAILED', {}, [
        { path: 'day', message: 'AAAA-MM-JJ passé attendu' },
      ]);
    }
    return toReconciliationDto(await this.reconciliation.run(day, user.id));
  }

  /** Export comptable du journal, CSV (H5). */
  @Get('journal.csv')
  @ApiProduces('text/csv')
  @ApiQuery({ name: 'from', example: '2026-11-01' })
  @ApiQuery({ name: 'to', example: '2026-11-30' })
  @ApiOkResponse({
    description: 'Journal au format CSV (séparateur point-virgule)',
    schema: { type: 'string' },
  })
  async journalCsv(
    @CurrentUser() user: AuthUser,
    @Query('from') from: string | undefined,
    @Query('to') to: string | undefined,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<string> {
    const csv = await this.journal.csv(from ?? '', to ?? '');
    await this.audit.record({
      actor: user,
      action: 'finance.journal_exported',
      entityType: 'journal',
      entityId: `${from}..${to}`,
      request,
    });
    response.setHeader('Content-Type', 'text/csv; charset=utf-8');
    response.setHeader(
      'Content-Disposition',
      `attachment; filename="tara-journal-${from}-${to}.csv"`,
    );
    return csv;
  }

  /**
   * Retrait gratuit d'une boutique ou d'un livreur : au-dessus de son seuil, aucun frais de
   * retrait ; en dessous, les frais Mobile Money sont retenus sur le montant envoyé.
   */
  @Get(':kind/:ownerId/free-payout')
  @ApiZodResponse(FreePayoutDto)
  freePayout(
    @Param('kind') kind: string,
    @Param('ownerId', ParseUUIDPipe) ownerId: string,
  ): Out<typeof FreePayoutDto> {
    return this.payouts.freePayoutSettings(beneficiaryOf(kind), ownerId);
  }

  @Put(':kind/:ownerId/free-payout')
  @ApiZodBody(FreePayoutBody)
  @ApiZodResponse(FreePayoutDto)
  async setFreePayout(
    @CurrentUser() user: AuthUser,
    @Param('kind') kind: string,
    @Param('ownerId', ParseUUIDPipe) ownerId: string,
    @ValidBody(FreePayoutBody) body: z.output<typeof FreePayoutBody>,
    @Req() request: Request,
  ): Out<typeof FreePayoutDto> {
    const beneficiary = beneficiaryOf(kind);
    const before = await this.payouts.freePayoutSettings(beneficiary, ownerId);
    await this.payouts.setFreePayoutFrom(beneficiary, ownerId, body.freeFrom);
    await this.audit.record({
      actor: user,
      action: 'finance.free_payout_set',
      entityType: beneficiary === 'MERCHANT' ? 'merchant' : 'rider',
      entityId: ownerId,
      before: { freePayoutFrom: before.custom },
      after: { freePayoutFrom: body.freeFrom },
      request,
    });
    return this.payouts.freePayoutSettings(beneficiary, ownerId);
  }

  /** Relevé mensuel PDF d'un marchand, pour le support et la finance. */
  @Get('merchants/:merchantId/statements/:month')
  @ApiProduces('application/pdf')
  @ApiOkResponse({ description: 'Relevé PDF', schema: { type: 'string', format: 'binary' } })
  async merchantStatement(
    @Param('merchantId', ParseUUIDPipe) merchantId: string,
    @Param('month') month: string,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    return pdfResponse(response, await this.statements.merchantStatement(merchantId, month));
  }

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

  /** Reversements par vue (à valider d'abord), avec le bénéficiaire et le nombre par vue. */
  @Get('payouts')
  @ApiZodQuery(AdminPayoutListQuery)
  @ApiZodResponse(AdminPayoutPageDto)
  async list(
    @ValidQuery(AdminPayoutListQuery) query: z.output<typeof AdminPayoutListQuery>,
  ): Out<typeof AdminPayoutPageDto> {
    const rows = await this.prisma.payout.findMany({
      where: {
        ...(query.status ? { status: query.status } : payoutView(query.view)),
        ...(query.cursor ? { id: { lt: query.cursor } } : {}),
      },
      orderBy: { id: 'desc' },
      take: query.limit + 1,
      include: PAYOUT_PEOPLE,
    });
    const page = pageOf(rows, query.limit);
    const counts = {} as Record<z.output<typeof AdminPayoutViewEnum>, number>;
    for (const view of AdminPayoutViewEnum.options) {
      counts[view] = await this.prisma.payout.count({ where: payoutView(view) });
    }
    return { items: page.items.map(toAdminPayoutDto), nextCursor: page.nextCursor, counts };
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

  /** Recharge du solde prépayé d'un livreur avec des espèces remises au bureau (G5). */
  @Post('riders/:riderId/topups')
  @MONEY_HEADER
  @ApiZodBody(OfficeDepositBody)
  @ApiZodResponse(z.object({ entryId: z.uuid(), balance: z.int() }), HttpStatus.CREATED)
  topUpAtOffice(
    @CurrentUser() user: AuthUser,
    @Param('riderId', ParseUUIDPipe) riderId: string,
    @ValidBody(OfficeDepositBody) body: z.output<typeof OfficeDepositBody>,
    @Headers('idempotency-key') key: string | undefined,
    @Req() request: Request,
  ): Promise<{ entryId: string; balance: number }> {
    return this.wallets.topUpRiderAtOffice(
      user,
      riderId,
      body.amount,
      body.note,
      requiredIdempotencyKey(key),
      request,
    );
  }

  /** Espèces remises au bureau par un livreur (G5, ancien fonctionnement). */
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

  /** Virement de trésorerie entre le bureau et le compte de l'agrégateur. */
  @Post('treasury-transfers')
  @MONEY_HEADER
  @ApiZodBody(TreasuryTransferBody)
  @ApiZodResponse(z.object({ entryId: z.uuid() }), HttpStatus.CREATED)
  treasuryTransfer(
    @CurrentUser() user: AuthUser,
    @ValidBody(TreasuryTransferBody) body: z.output<typeof TreasuryTransferBody>,
    @Headers('idempotency-key') key: string | undefined,
    @Req() request: Request,
  ): Promise<{ entryId: string }> {
    return this.wallets.treasuryTransfer(
      user,
      body.direction,
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

/** « merchants » ou « riders » dans l'adresse. */
function beneficiaryOf(kind: string): 'MERCHANT' | 'RIDER' {
  if (kind === 'merchants') return 'MERCHANT';
  if (kind === 'riders') return 'RIDER';
  throw AppError.notFound();
}
