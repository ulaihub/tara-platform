import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service.js';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import type { PromoCode } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  PricingGridBody,
  PricingGridDto,
  PricingGridListQuery,
  PromoCodeBody,
  PromoCodeDto,
  PromoPatchBody,
  QuoteBody,
  QuoteDto,
  SurchargeCodeEnum,
  SurchargePatchBody,
} from './pricing.schemas.js';
import { PricingService } from './pricing.service.js';

@ApiTags('Commandes')
@ApiBearerAuth()
@Controller('orders')
export class QuoteController {
  constructor(private readonly pricing: PricingService) {}

  /** Prix d'une livraison avant commande (C2), promotion comprise. */
  @Post('quote')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(QuoteBody)
  @ApiZodResponse(QuoteDto)
  quote(
    @CurrentUser() user: AuthUser,
    @ValidBody(QuoteBody) body: z.output<typeof QuoteBody>,
  ): Promise<z.output<typeof QuoteDto>> {
    return this.pricing.publicQuote(user, body);
  }
}

@ApiTags('Back-office · tarifs')
@ApiBearerAuth()
@Roles('ADMIN')
@Controller('admin')
export class AdminPricingController {
  constructor(
    private readonly pricing: PricingService,
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  @Get('pricing-grids')
  @ApiZodQuery(PricingGridListQuery)
  @ApiZodResponse(z.array(PricingGridDto))
  list(
    @ValidQuery(PricingGridListQuery) query: z.output<typeof PricingGridListQuery>,
  ): Promise<z.output<typeof PricingGridDto>[]> {
    return this.pricing.listGrids(query.city);
  }

  /** Nouvelle version de grille (C7) ; les commandes passées gardent leur tarif. */
  @Post('pricing-grids')
  @ApiZodBody(PricingGridBody)
  @ApiZodResponse(PricingGridDto, HttpStatus.CREATED)
  create(
    @CurrentUser() user: AuthUser,
    @ValidBody(PricingGridBody) body: z.output<typeof PricingGridBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof PricingGridDto>> {
    return this.pricing.createGrid(user, body, request);
  }

  @Post('pricing-grids/:id/activate')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(PricingGridDto)
  activate(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Req() request: Request,
  ): Promise<z.output<typeof PricingGridDto>> {
    return this.pricing.activate(user, id, request);
  }

  @Patch('pricing-grids/:id/surcharges/:code')
  @ApiZodBody(SurchargePatchBody)
  @ApiZodResponse(PricingGridDto)
  toggleSurcharge(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('code') code: string,
    @ValidBody(SurchargePatchBody) body: z.output<typeof SurchargePatchBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof PricingGridDto>> {
    const parsed = SurchargeCodeEnum.safeParse(code);
    if (!parsed.success) throw AppError.notFound();
    return this.pricing.toggleSurcharge(user, id, parsed.data, body.active, request);
  }

  @Get('promo-codes')
  @ApiZodResponse(z.array(PromoCodeDto))
  async promos(): Promise<z.output<typeof PromoCodeDto>[]> {
    const promos = await this.prisma.promoCode.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: { _count: { select: { redemptions: true } } },
    });
    return promos.map((promo) => this.toPromoDto(promo, promo._count.redemptions));
  }

  @Post('promo-codes')
  @ApiZodBody(PromoCodeBody)
  @ApiZodResponse(PromoCodeDto, HttpStatus.CREATED)
  async createPromo(
    @CurrentUser() user: AuthUser,
    @ValidBody(PromoCodeBody) body: z.output<typeof PromoCodeBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof PromoCodeDto>> {
    const existing = await this.prisma.promoCode.findUnique({ where: { code: body.code } });
    if (existing) throw AppError.conflict('PROMO_ALREADY_EXISTS');
    const promo = await this.prisma.promoCode.create({
      data: {
        code: body.code,
        kind: body.kind,
        value: body.value,
        maxRedemptions: body.maxRedemptions ?? null,
        perUserLimit: body.perUserLimit,
        newCustomersOnly: body.newCustomersOnly,
        validFrom: body.validFrom ? new Date(body.validFrom) : new Date(),
        validTo: body.validTo ? new Date(body.validTo) : null,
      },
    });
    await this.audit.record({
      actor: user,
      action: 'promo_code.created',
      entityType: 'promo_code',
      entityId: promo.id,
      after: promo,
      request,
    });
    return this.toPromoDto(promo, 0);
  }

  @Patch('promo-codes/:id')
  @ApiZodBody(PromoPatchBody)
  @ApiZodResponse(PromoCodeDto)
  async patchPromo(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(PromoPatchBody) body: z.output<typeof PromoPatchBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof PromoCodeDto>> {
    const { count } = await this.prisma.promoCode.updateMany({
      where: { id },
      data: { active: body.active },
    });
    if (count !== 1) throw AppError.notFound();
    await this.audit.record({
      actor: user,
      action: 'promo_code.updated',
      entityType: 'promo_code',
      entityId: id,
      after: body,
      request,
    });
    const promo = await this.prisma.promoCode.findUniqueOrThrow({
      where: { id },
      include: { _count: { select: { redemptions: true } } },
    });
    return this.toPromoDto(promo, promo._count.redemptions);
  }

  private toPromoDto(promo: PromoCode, redemptions: number): z.output<typeof PromoCodeDto> {
    return {
      id: promo.id,
      code: promo.code,
      kind: promo.kind,
      value: promo.value,
      maxRedemptions: promo.maxRedemptions,
      perUserLimit: promo.perUserLimit,
      newCustomersOnly: promo.newCustomersOnly,
      validFrom: promo.validFrom.toISOString(),
      validTo: promo.validTo?.toISOString() ?? null,
      active: promo.active,
      redemptions,
    };
  }
}
