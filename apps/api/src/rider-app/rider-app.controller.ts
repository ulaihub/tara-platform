import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Inject,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import { pageSchema } from '../common/pagination.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import {
  AssignBody,
  CandidateDto,
  DispatchStateDto,
  OfferDto,
} from '../dispatch/dispatch.schemas.js';
import { DispatchService } from '../dispatch/dispatch.service.js';
import { RiderLocationService } from '../dispatch/rider-location.service.js';
import { AuditService } from '../audit/audit.service.js';
import { OrderDto } from '../orders/orders.schemas.js';
import { OrdersService } from '../orders/orders.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { AppError } from '../common/errors/app-error.js';
import { OrderSupportService } from './order-support.service.js';
import {
  DeliverBody,
  EarningsDto,
  EarningsQuery,
  FailBody,
  FailureDecisionBody,
  PickupBody,
  PositionActionBody,
  PositionBody,
  PresenceBody,
  PresenceDto,
  ReleaseBody,
  RiderConfigDto,
  ResolveAlertBody,
  ReturnBody,
  RiderOrderDto,
  RiderOrdersQuery,
  RiderRouteDto,
  RouteQuery,
  SafetyAlertBody,
  SafetyAlertDto,
  SafetyAlertListQuery,
  ValidateDeliveryBody,
} from './rider-app.schemas.js';
import { RiderOrdersService } from './rider-orders.service.js';
import { SafetyAlertsService } from './safety-alerts.service.js';

type Out<T extends z.ZodType> = Promise<z.output<T>>;

function position(body: z.output<typeof PositionBody>) {
  return {
    latitude: body.latitude,
    longitude: body.longitude,
    heading: body.heading,
    speed: body.speed,
    accuracy: body.accuracy,
    mocked: body.mocked,
    at: body.recordedAt ? new Date(body.recordedAt) : new Date(),
  };
}

/** Application livreur (E1 à E9) : présence, propositions, courses, gains, alerte. */
@ApiTags('Livreur')
@ApiBearerAuth()
@Roles('RIDER')
@Controller('rider')
export class RiderAppController {
  constructor(
    private readonly location: RiderLocationService,
    private readonly dispatch: DispatchService,
    private readonly orders: RiderOrdersService,
    private readonly alerts: SafetyAlertsService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Réglages de l'app : pays, devise, opérateurs, ligne de secours et du support.
   * Lus au démarrage et gardés sur le téléphone pour l'usage hors connexion.
   */
  @Get('config')
  @ApiZodResponse(RiderConfigDto)
  config(): z.output<typeof RiderConfigDto> {
    return {
      country: { code: 'CM', dialCode: '+237', currency: 'XAF' },
      safetyHotline: this.env.SAFETY_HOTLINE_PHONE,
      supportPhone: this.env.SUPPORT_PHONE ?? null,
      mobileMoneyOperators: [
        { code: 'MTN', name: 'MTN Mobile Money' },
        { code: 'ORANGE', name: 'Orange Money' },
      ],
      offerTimeoutSeconds: this.env.DISPATCH_OFFER_TIMEOUT_SECONDS,
    };
  }

  /** Passage en ligne ou hors ligne (E1). En ligne : pièces valides exigées (D4). */
  @Put('presence')
  @ApiZodBody(PresenceBody)
  @ApiZodResponse(PresenceDto)
  presence(
    @CurrentUser() user: AuthUser,
    @ValidBody(PresenceBody) body: z.output<typeof PresenceBody>,
  ): Out<typeof PresenceDto> {
    return this.location.setPresence(user.id, body.online, position(body));
  }

  @Get('presence')
  @ApiZodResponse(PresenceDto)
  async presenceState(@CurrentUser() user: AuthUser): Out<typeof PresenceDto> {
    return {
      online: await this.location.isOnline(user.id),
      blockers: await this.location.blockers(user.id),
    };
  }

  /**
   * Position toutes les 10 à 15 s (F1). La connexion temps réel (événement
   * `rider.location`) est préférable quand elle est ouverte : moins de données.
   */
  @Post('location')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiZodBody(PositionBody)
  async locate(
    @CurrentUser() user: AuthUser,
    @ValidBody(PositionBody) body: z.output<typeof PositionBody>,
  ): Promise<void> {
    await this.location.update(user.id, position(body));
  }

  @Get('offers')
  @ApiZodResponse(z.array(OfferDto))
  offers(@CurrentUser() user: AuthUser): Out<z.ZodArray<typeof OfferDto>> {
    return this.dispatch.pendingOffersFor(user.id);
  }

  @Post('offers/:id/accept')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(RiderOrderDto)
  async accept(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Out<typeof RiderOrderDto> {
    const order = await this.dispatch.accept(id, user.id);
    return this.orders.get(user.id, order.id);
  }

  @Post('offers/:id/decline')
  @HttpCode(HttpStatus.NO_CONTENT)
  async decline(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<void> {
    await this.dispatch.decline(id, user.id);
  }

  /** Courses en cours ou historique (E9). */
  @Get('orders')
  @ApiZodQuery(RiderOrdersQuery)
  @ApiZodResponse(pageSchema(RiderOrderDto))
  list(
    @CurrentUser() user: AuthUser,
    @ValidQuery(RiderOrdersQuery) query: z.output<typeof RiderOrdersQuery>,
  ): Promise<{ items: z.output<typeof RiderOrderDto>[]; nextCursor: string | null }> {
    return this.orders.list(user.id, query);
  }

  @Get('orders/:id')
  @ApiZodResponse(RiderOrderDto)
  get(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Out<typeof RiderOrderDto> {
    return this.orders.get(user.id, id);
  }

  /**
   * Itinéraire de la position du livreur à la prochaine étape (E2) : tracé routier (OSRM)
   * ou ligne droite estimée. L'app le redemande quand le livreur s'est déplacé.
   */
  @Get('orders/:id/route')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiZodQuery(RouteQuery)
  @ApiZodResponse(RiderRouteDto)
  route(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidQuery(RouteQuery) query: z.output<typeof RouteQuery>,
  ): Out<typeof RiderRouteDto> {
    return this.orders.route(user.id, id, query);
  }

  /** Enlèvement : code de l'expéditeur et photo du colis (E3). */
  @Post('orders/:id/pickup')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(PickupBody)
  @ApiZodResponse(RiderOrderDto)
  pickup(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(PickupBody) body: z.output<typeof PickupBody>,
  ): Out<typeof RiderOrderDto> {
    return this.orders.pickup(user.id, id, body);
  }

  @Post('orders/:id/depart')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(PositionActionBody)
  @ApiZodResponse(RiderOrderDto)
  depart(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(PositionActionBody) body: z.output<typeof PositionActionBody>,
  ): Out<typeof RiderOrderDto> {
    return this.orders.depart(user.id, id, body);
  }

  /** Livraison : code du destinataire et photo ; sans code, validation par le support (E4). */
  @Post('orders/:id/deliver')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(DeliverBody)
  @ApiZodResponse(RiderOrderDto)
  deliver(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(DeliverBody) body: z.output<typeof DeliverBody>,
  ): Out<typeof RiderOrderDto> {
    return this.orders.deliver(user.id, id, body);
  }

  /** Échec de livraison : motif, photo du lieu, preuve d'appel (E6). */
  @Post('orders/:id/fail')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(FailBody)
  @ApiZodResponse(RiderOrderDto)
  fail(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(FailBody) body: z.output<typeof FailBody>,
  ): Out<typeof RiderOrderDto> {
    return this.orders.fail(user.id, id, body);
  }

  @Post('orders/:id/retry')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(PositionActionBody)
  @ApiZodResponse(RiderOrderDto)
  retry(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(PositionActionBody) body: z.output<typeof PositionActionBody>,
  ): Out<typeof RiderOrderDto> {
    return this.orders.retry(user.id, id, body);
  }

  @Post('orders/:id/return')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(ReturnBody)
  @ApiZodResponse(RiderOrderDto)
  returnToSender(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(ReturnBody) body: z.output<typeof ReturnBody>,
  ): Out<typeof RiderOrderDto> {
    return this.orders.returnToSender(user.id, id, body);
  }

  /** Rendre une course pas encore enlevée (imprévu) : elle repart en recherche. */
  @Post('orders/:id/release')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodBody(ReleaseBody)
  async release(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(ReleaseBody) body: z.output<typeof ReleaseBody>,
  ): Promise<void> {
    await this.orders.release(user.id, id, body.reason);
  }

  /** Gains et courses du jour, de la semaine ou du mois (E9). */
  @Get('earnings')
  @ApiZodQuery(EarningsQuery)
  @ApiZodResponse(EarningsDto)
  earnings(
    @CurrentUser() user: AuthUser,
    @ValidQuery(EarningsQuery) query: z.output<typeof EarningsQuery>,
  ): Out<typeof EarningsDto> {
    return this.orders.earnings(user.id, query.period);
  }

  /** Bouton d'alerte : position envoyée au dispatch et aux numéros d'astreinte (E8). */
  @Post('alerts')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiZodBody(SafetyAlertBody)
  @ApiZodResponse(SafetyAlertDto, HttpStatus.CREATED)
  alert(
    @CurrentUser() user: AuthUser,
    @ValidBody(SafetyAlertBody) body: z.output<typeof SafetyAlertBody>,
  ): Out<typeof SafetyAlertDto> {
    return this.alerts.raise(user, body);
  }

  /** Annulation de sa propre alerte : l'équipe est prévenue et rappelle le livreur (E8). */
  @Post('alerts/:id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(SafetyAlertDto)
  cancelAlert(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Out<typeof SafetyAlertDto> {
    return this.alerts.cancel(user, id);
  }
}

/** Choix de l'expéditeur après un échec de livraison (E6). */
@ApiTags('Commandes')
@ApiBearerAuth()
@Controller('orders')
export class SenderDecisionsController {
  constructor(private readonly support: OrderSupportService) {}

  @Post(':id/failure-decision')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodBody(FailureDecisionBody)
  async failureDecision(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(FailureDecisionBody) body: z.output<typeof FailureDecisionBody>,
  ): Promise<void> {
    await this.support.failureDecision(user, id, body.decision);
  }
}

/** Attribution manuelle et suivi des recherches de livreur (D3). */
@ApiTags('Back-office · attribution')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER')
@Controller('admin/orders')
export class AdminDispatchController {
  constructor(
    private readonly dispatch: DispatchService,
    private readonly orders: OrdersService,
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  @Get(':id/dispatch')
  @ApiZodResponse(DispatchStateDto)
  async state(@Param('id', ParseUUIDPipe) id: string): Out<typeof DispatchStateDto> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: { offers: { orderBy: { offeredAt: 'desc' }, take: 100 } },
    });
    if (!order) throw AppError.notFound('ORDER_NOT_FOUND');
    return {
      orderId: order.id,
      status: order.status,
      searchingSince: order.searchingSince?.toISOString() ?? null,
      alerted: order.dispatchAlertedAt !== null,
      offers: order.offers.map((offer) => ({
        id: offer.id,
        riderId: offer.riderId,
        round: offer.round,
        approachMeters: offer.approachMeters,
        offeredAt: offer.offeredAt.toISOString(),
        expiresAt: offer.expiresAt.toISOString(),
        respondedAt: offer.respondedAt?.toISOString() ?? null,
        outcome: offer.outcome,
      })),
    };
  }

  /** Livreurs proches, du mieux placé au moins bien placé, avec les raisons d'exclusion. */
  @Get(':id/candidates')
  @ApiZodResponse(z.array(CandidateDto))
  candidates(@Param('id', ParseUUIDPipe) id: string): Out<z.ZodArray<typeof CandidateDto>> {
    return this.dispatch.candidatesFor(id);
  }

  /** Confie la course à un livreur, y compris en la retirant à un autre (réattribution). */
  @Post(':id/assign')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(AssignBody)
  @ApiZodResponse(OrderDto)
  async assign(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(AssignBody) body: z.output<typeof AssignBody>,
    @Req() request: Request,
  ): Out<typeof OrderDto> {
    const before = await this.prisma.order.findUnique({ where: { id } });
    await this.dispatch.assignManually(id, body.riderId, user.id, body.note);
    await this.audit.record({
      actor: user,
      action: 'order.assign',
      entityType: 'order',
      entityId: id,
      before: { status: before?.status, riderId: before?.riderId },
      after: { status: 'ASSIGNED', riderId: body.riderId, note: body.note },
      request,
    });
    return this.orders.get(user, id);
  }
}

/** Support : livraisons sans code et alertes de sécurité (E4, E8). */
@ApiTags('Back-office · support')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER', 'SUPPORT')
@Controller('admin')
export class AdminSupportController {
  constructor(
    private readonly support: OrderSupportService,
    private readonly alerts: SafetyAlertsService,
  ) {}

  @Post('orders/:id/validate-delivery')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodBody(ValidateDeliveryBody)
  async validateDelivery(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(ValidateDeliveryBody) body: z.output<typeof ValidateDeliveryBody>,
    @Req() request: Request,
  ): Promise<void> {
    await this.support.validateDelivery(user, id, body.note, request);
  }

  @Get('safety-alerts')
  @ApiZodQuery(SafetyAlertListQuery)
  @ApiZodResponse(z.array(SafetyAlertDto))
  listAlerts(
    @ValidQuery(SafetyAlertListQuery) query: z.output<typeof SafetyAlertListQuery>,
  ): Out<z.ZodArray<typeof SafetyAlertDto>> {
    return this.alerts.list(query.status);
  }

  @Post('safety-alerts/:id/acknowledge')
  @HttpCode(HttpStatus.OK)
  @ApiZodResponse(SafetyAlertDto)
  acknowledge(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Out<typeof SafetyAlertDto> {
    return this.alerts.acknowledge(id, user);
  }

  @Post('safety-alerts/:id/resolve')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(ResolveAlertBody)
  @ApiZodResponse(SafetyAlertDto)
  resolve(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(ResolveAlertBody) body: z.output<typeof ResolveAlertBody>,
  ): Out<typeof SafetyAlertDto> {
    return this.alerts.resolve(id, user, body.resolution);
  }
}
