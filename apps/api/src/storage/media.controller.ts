import { Body, Controller, HttpStatus, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { ApiZodResponse, ZodValidationPipe } from '../common/validation/zod.js';
import { MediaService } from './media.service.js';

const UploadMediaBody = z.object({
  kind: z.enum(['ADDRESS_PHOTO', 'VOICE_NOTE', 'PROOF_PHOTO', 'PARCEL_PHOTO']),
});

export const MediaDto = z
  .object({
    key: z.string().meta({ description: 'Clé à transmettre dans photoKey ou voiceNoteKey' }),
    kind: z.enum(['ADDRESS_PHOTO', 'VOICE_NOTE', 'KYC_DOCUMENT', 'PROOF_PHOTO', 'PARCEL_PHOTO']),
    mimeType: z.string(),
    sizeBytes: z.int(),
  })
  .meta({ id: 'Media' });

@ApiTags('Fichiers')
@ApiBearerAuth()
@Controller('media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  /**
   * Photo de façade ou note vocale d'une adresse (B2) ; photo de preuve d'enlèvement, de
   * livraison ou d'échec, réservée aux livreurs (E3, E4, E6).
   */
  @Post()
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 1_000_000, files: 1 } }))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file', 'kind'],
      properties: {
        file: { type: 'string', format: 'binary' },
        kind: {
          type: 'string',
          enum: ['ADDRESS_PHOTO', 'VOICE_NOTE', 'PROOF_PHOTO', 'PARCEL_PHOTO'],
        },
      },
    },
  })
  @ApiZodResponse(MediaDto, HttpStatus.CREATED)
  async upload(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File | undefined,
    @Body(new ZodValidationPipe(UploadMediaBody)) body: z.output<typeof UploadMediaBody>,
  ): Promise<z.output<typeof MediaDto>> {
    if (!file)
      throw AppError.badRequest('VALIDATION_FAILED', {}, [{ path: 'file', message: 'requis' }]);
    if (body.kind === 'PROOF_PHOTO' && !user.roles.includes('RIDER')) throw AppError.forbidden();
    const stored = await this.media.store(user.id, body.kind, file);
    return {
      key: stored.key,
      kind: stored.kind,
      mimeType: stored.mimeType,
      sizeBytes: stored.sizeBytes,
    };
  }
}
