import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import { ApiZodBody, ApiZodResponse, ValidBody } from '../common/validation/zod.js';
import {
  OfficeHandOverBody,
  OfficeReturnDto,
  OfficeUnclaimedBody,
  ReturnQuoteDto,
} from './office-returns.schemas.js';
import { OfficeReturnsService } from './office-returns.service.js';

/** Retour sans dette, côté expéditeur : prix du retour et paiement au bureau. */
@ApiTags('Commandes')
@ApiBearerAuth()
@Controller('orders')
export class SenderOfficeController {
  constructor(private readonly office: OfficeReturnsService) {}

  /**
   * Après un échec, ou colis gardé au bureau : frais du retour, part prise sur le solde
   * (sans dette) et reste à payer maintenant.
   */
  @Get(':id/return-quote')
  @ApiZodResponse(ReturnQuoteDto)
  quote(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<z.output<typeof ReturnQuoteDto>> {
    return this.office.quote(user, id);
  }

  /**
   * Colis gardé au bureau : frais payés avec le solde (422 RETURN_PAYMENT_REQUIRED et le
   * montant à recharger s'il ne suffit pas). Payé : code de retrait envoyé par SMS.
   */
  @Post(':id/office-payment')
  @HttpCode(HttpStatus.NO_CONTENT)
  async pay(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string): Promise<void> {
    await this.office.pay(user, id);
  }
}

/** Colis gardés au bureau Tara : liste, remise à l'expéditeur, colis non réclamé. */
@ApiTags('Back-office · bureau')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER', 'SUPPORT')
@Controller('admin/office-returns')
export class AdminOfficeController {
  constructor(private readonly office: OfficeReturnsService) {}

  @Get()
  @ApiZodResponse(z.array(OfficeReturnDto))
  list(): Promise<z.output<typeof OfficeReturnDto>[]> {
    return this.office.list();
  }

  /** Remis à l'expéditeur : contre le code de retrait, ou contre les frais en espèces. */
  @Post(':id/hand-over')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodBody(OfficeHandOverBody)
  async handOver(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(OfficeHandOverBody) body: z.output<typeof OfficeHandOverBody>,
    @Req() request: Request,
  ): Promise<void> {
    await this.office.handOver(user, id, body, request);
  }

  /** Garde finie sans que l'expéditeur vienne : la note dit ce que Tara a fait du colis. */
  @Post(':id/unclaimed')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodBody(OfficeUnclaimedBody)
  async unclaimed(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(OfficeUnclaimedBody) body: z.output<typeof OfficeUnclaimedBody>,
    @Req() request: Request,
  ): Promise<void> {
    await this.office.unclaimed(user, id, body.note, request);
  }
}
