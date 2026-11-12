import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { z } from 'zod';
import { Roles } from '../auth/decorators.js';
import { ApiZodQuery, ApiZodResponse, ValidQuery } from '../common/validation/zod.js';
import {
  AdminMerchantDto,
  AdminMerchantListQuery,
  AdminMerchantPageDto,
} from './admin-merchants.schemas.js';
import { AdminMerchantsService } from './admin-merchants.service.js';

@ApiTags('Back-office · marchands')
@ApiBearerAuth()
@Roles('ADMIN', 'FINANCE')
@Controller('admin/merchants')
export class AdminMerchantsController {
  constructor(private readonly merchants: AdminMerchantsService) {}

  /** Boutiques, les plus actives du mois d'abord, avec tarif pro et solde (H4). */
  @Get()
  @ApiZodQuery(AdminMerchantListQuery)
  @ApiZodResponse(AdminMerchantPageDto)
  list(
    @ValidQuery(AdminMerchantListQuery) query: z.output<typeof AdminMerchantListQuery>,
  ): Promise<z.output<typeof AdminMerchantPageDto>> {
    return this.merchants.list(query);
  }

  @Get(':id')
  @ApiZodResponse(AdminMerchantDto)
  detail(@Param('id', ParseUUIDPipe) id: string): Promise<z.output<typeof AdminMerchantDto>> {
    return this.merchants.detail(id);
  }
}
