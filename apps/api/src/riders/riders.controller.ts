import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Req,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import type { Request, Response } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
  ZodValidationPipe,
} from '../common/validation/zod.js';
import {
  AdminRiderDto,
  AdminRiderListQuery,
  AdminRiderPageDto,
  ApplyRiderBody,
  DOCUMENT_LABELS,
  DocumentRequirementDto,
  EmergencyContactBody,
  EXPIRING_DOCUMENTS,
  KycDocumentDto,
  REQUIRED_DOCUMENTS,
  ReviewDocumentBody,
  RiderDecisionBody,
  RiderProfileDto,
  RiderReliabilityDto,
  VehicleBody,
  UploadDocumentBody,
} from './riders.schemas.js';
import { RiderReliabilityService } from './rider-reliability.service.js';
import { RidersService } from './riders.service.js';

@ApiTags('Livreurs')
@ApiBearerAuth()
@Controller('riders')
export class RidersController {
  constructor(private readonly riders: RidersService) {}

  /** Candidature livreur (A3). */
  @Post('apply')
  @ApiZodBody(ApplyRiderBody)
  @ApiZodResponse(RiderProfileDto, HttpStatus.CREATED)
  apply(
    @CurrentUser() user: AuthUser,
    @ValidBody(ApplyRiderBody) body: z.output<typeof ApplyRiderBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof RiderProfileDto>> {
    return this.riders.apply(user, body, request);
  }

  /** Pièces à fournir, dans l'ordre d'affichage : l'app n'en code aucune en dur (A3). */
  @Get('requirements')
  @ApiZodResponse(z.array(DocumentRequirementDto))
  requirements(): z.output<typeof DocumentRequirementDto>[] {
    return REQUIRED_DOCUMENTS.map((group) => ({
      types: group.map((type) => ({
        type,
        label: DOCUMENT_LABELS[type],
        asksExpiry: EXPIRING_DOCUMENTS.includes(type),
      })),
    }));
  }

  @Get('me')
  @Roles('RIDER')
  @ApiZodResponse(RiderProfileDto)
  me(@CurrentUser() user: AuthUser): Promise<z.output<typeof RiderProfileDto>> {
    return this.riders.myProfile(user.id);
  }

  /** Contact d'urgence, prévenu par SMS en cas d'alerte de sécurité (facultatif). */
  @Put('me/emergency-contact')
  @Roles('RIDER')
  @ApiZodBody(EmergencyContactBody)
  @ApiZodResponse(RiderProfileDto)
  setEmergencyContact(
    @CurrentUser() user: AuthUser,
    @ValidBody(EmergencyContactBody) body: z.output<typeof EmergencyContactBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof RiderProfileDto>> {
    return this.riders.setEmergencyContact(user, body, request);
  }

  /** Marque, couleur et plaque du véhicule (montrées à l'expéditeur). */
  @Put('me/vehicle')
  @Roles('RIDER')
  @ApiZodBody(VehicleBody)
  @ApiZodResponse(RiderProfileDto)
  setVehicle(
    @CurrentUser() user: AuthUser,
    @ValidBody(VehicleBody) body: z.output<typeof VehicleBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof RiderProfileDto>> {
    return this.riders.setVehicle(user, body, request);
  }

  @Delete('me/emergency-contact')
  @Roles('RIDER')
  @ApiZodResponse(RiderProfileDto)
  removeEmergencyContact(
    @CurrentUser() user: AuthUser,
    @Req() request: Request,
  ): Promise<z.output<typeof RiderProfileDto>> {
    return this.riders.setEmergencyContact(user, null, request);
  }

  /** Envoi d'une pièce : photo ou PDF de 5 Mo maximum, chiffré au stockage (A3). */
  @Post('me/documents')
  @Roles('RIDER')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5_000_000, files: 1 } }))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file', 'type'],
      properties: {
        file: { type: 'string', format: 'binary' },
        type: { $ref: '#/components/schemas/KycDocumentType' },
        expiresOn: { type: 'string', format: 'date' },
      },
    },
  })
  @ApiZodResponse(KycDocumentDto, HttpStatus.CREATED)
  uploadDocument(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File | undefined,
    @Body(new ZodValidationPipe(UploadDocumentBody)) body: z.output<typeof UploadDocumentBody>,
  ): Promise<z.output<typeof KycDocumentDto>> {
    if (!file)
      throw AppError.badRequest('VALIDATION_FAILED', {}, [{ path: 'file', message: 'requis' }]);
    return this.riders.uploadDocument(user, body, file);
  }
}

/** Validation des livreurs par l'équipe des opérations (H3). */
@ApiTags('Back-office · livreurs')
@ApiBearerAuth()
@Roles('ADMIN', 'DISPATCHER')
@Controller('admin')
export class AdminRidersController {
  constructor(
    private readonly riders: RidersService,
    private readonly reliability: RiderReliabilityService,
  ) {}

  /** Liste par vue (à examiner, en attente, actifs…), recherche par nom, numéro ou plaque. */
  @Get('riders')
  @ApiZodQuery(AdminRiderListQuery)
  @ApiZodResponse(AdminRiderPageDto)
  list(
    @ValidQuery(AdminRiderListQuery) query: z.output<typeof AdminRiderListQuery>,
  ): Promise<z.output<typeof AdminRiderPageDto>> {
    return this.riders.list(query);
  }

  /** Fiabilité sur 30 jours et depuis l'inscription, historique des décisions (H3). */
  @Get('riders/:riderId/reliability')
  @ApiZodResponse(RiderReliabilityDto)
  riderReliability(
    @Param('riderId', ParseUUIDPipe) riderId: string,
  ): Promise<z.output<typeof RiderReliabilityDto>> {
    return this.reliability.reliability(riderId);
  }

  @Get('riders/:riderId')
  @ApiZodResponse(AdminRiderDto)
  get(@Param('riderId', ParseUUIDPipe) riderId: string): Promise<z.output<typeof AdminRiderDto>> {
    return this.riders.get(riderId);
  }

  @Post('riders/:riderId/decision')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(RiderDecisionBody)
  @ApiZodResponse(AdminRiderDto)
  decide(
    @CurrentUser() user: AuthUser,
    @Param('riderId', ParseUUIDPipe) riderId: string,
    @ValidBody(RiderDecisionBody) body: z.output<typeof RiderDecisionBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof AdminRiderDto>> {
    return this.riders.decide(user, riderId, body, request);
  }

  /** Fichier déchiffré d'une pièce ; la consultation est inscrite au journal d'audit. */
  @Get('kyc-documents/:documentId/file')
  async documentFile(
    @CurrentUser() user: AuthUser,
    @Param('documentId', ParseUUIDPipe) documentId: string,
    @Req() request: Request,
    @Res() response: Response,
  ): Promise<void> {
    const file = await this.riders.documentFile(user, documentId, request);
    response
      .status(HttpStatus.OK)
      .set({
        'Content-Type': file.mimeType,
        'Cache-Control': 'no-store',
        // Jamais affiché dans la page du back-office : téléchargé comme pièce jointe.
        'Content-Disposition': `attachment; filename="piece-${documentId}"`,
      })
      .send(file.buffer);
  }

  @Post('kyc-documents/:documentId/review')
  @HttpCode(HttpStatus.OK)
  @ApiZodBody(ReviewDocumentBody)
  @ApiZodResponse(KycDocumentDto)
  review(
    @CurrentUser() user: AuthUser,
    @Param('documentId', ParseUUIDPipe) documentId: string,
    @ValidBody(ReviewDocumentBody) body: z.output<typeof ReviewDocumentBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof KycDocumentDto>> {
    return this.riders.reviewDocument(user, documentId, body, request);
  }
}
