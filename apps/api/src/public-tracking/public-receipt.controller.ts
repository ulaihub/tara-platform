import { Controller, Get, Param } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { z } from 'zod';
import { Public } from '../auth/decorators.js';
import { ApiZodResponse } from '../common/validation/zod.js';
import { PublicReceiptDto } from './public-receipt.schemas.js';
import { PublicReceiptService } from './public-receipt.service.js';

/** « Vérifier un reçu » : le QR du reçu imprimé ouvre cette vérification, sans compte. */
@ApiTags('Public')
@Public()
@Throttle({ default: { limit: 30, ttl: 60_000 } })
@Controller('public/receipts')
export class PublicReceiptController {
  constructor(private readonly receipts: PublicReceiptService) {}

  @Get(':code')
  @ApiZodResponse(PublicReceiptDto)
  verify(@Param('code') code: string): Promise<z.output<typeof PublicReceiptDto>> {
    return this.receipts.verify(code);
  }
}
