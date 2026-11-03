import { Controller, HttpCode, HttpStatus, Param, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import { AppError } from '../common/errors/app-error.js';
import { ApiZodBody, ValidBody } from '../common/validation/zod.js';
import { PrismaService } from '../prisma/prisma.service.js';

export const PushTokenBody = z
  .object({
    /** Jeton FCM de l'appareil ; null pour ne plus recevoir de notifications. */
    pushToken: z.string().min(20).max(4096).nullable(),
  })
  .meta({ id: 'PushTokenBody' });

@ApiTags('Mon compte')
@ApiBearerAuth()
@Controller('me/devices')
export class DevicesController {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Jeton de notifications de l'appareil (F3), à envoyer après la connexion et à chaque
   * renouvellement par Firebase. Un même jeton n'appartient qu'à un seul compte.
   */
  @Put(':installationId/push-token')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiZodBody(PushTokenBody)
  async setPushToken(
    @CurrentUser() user: AuthUser,
    @Param('installationId') installationId: string,
    @ValidBody(PushTokenBody) body: z.output<typeof PushTokenBody>,
  ): Promise<void> {
    const device = await this.prisma.device.findUnique({
      where: { userId_installationId: { userId: user.id, installationId } },
    });
    if (!device) throw AppError.notFound();
    await this.prisma.$transaction([
      // Téléphone passé d'un compte à l'autre : l'ancien compte ne reçoit plus ses notifications.
      ...(body.pushToken
        ? [
            this.prisma.device.updateMany({
              where: { pushToken: body.pushToken, id: { not: device.id } },
              data: { pushToken: null },
            }),
          ]
        : []),
      this.prisma.device.update({
        where: { id: device.id },
        data: { pushToken: body.pushToken, lastSeenAt: new Date() },
      }),
    ]);
  }
}
