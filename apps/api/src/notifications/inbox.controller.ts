import { Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import { resolveLocale } from '../common/i18n/locale.js';
import { ApiZodResponse } from '../common/validation/zod.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { type PushTemplate, renderPush } from './push-templates.js';

/** Au plus ce nombre de notifications dans la cloche ; les plus anciennes restent en base. */
export const INBOX_LIMIT = 50;

export const InboxItemDto = z
  .object({
    id: z.uuid(),
    /** Modèle de la notification (ORDER_DELIVERED, PAYOUT_SENT…) : icône et écran à ouvrir. */
    kind: z.string(),
    title: z.string(),
    body: z.string(),
    orderId: z.uuid().nullable(),
    read: z.boolean(),
    createdAt: z.iso.datetime(),
  })
  .meta({ id: 'InboxItem' });

export const InboxDto = z
  .object({ items: z.array(InboxItemDto), unread: z.int() })
  .meta({ id: 'Inbox' });

@ApiTags('Mon compte')
@ApiBearerAuth()
@Controller('me/notifications')
export class InboxController {
  constructor(private readonly prisma: PrismaService) {}

  /** Cloche de l'app : notifications du compte, les plus récentes d'abord, et le nombre de non lues. */
  @Get()
  @ApiZodResponse(InboxDto)
  async list(@CurrentUser() user: AuthUser): Promise<z.output<typeof InboxDto>> {
    const locale = resolveLocale(undefined, user.locale);
    const [rows, unread] = await Promise.all([
      this.prisma.inboxItem.findMany({
        where: { userId: user.id },
        orderBy: { createdAt: 'desc' },
        take: INBOX_LIMIT,
      }),
      this.prisma.inboxItem.count({ where: { userId: user.id, readAt: null } }),
    ]);
    return {
      unread,
      items: rows.map((row) => {
        const { title, body } = renderPush(
          row.template as PushTemplate,
          locale,
          row.params as Record<string, string | number>,
        );
        return {
          id: row.id,
          kind: row.template,
          title,
          body,
          orderId: row.orderId,
          read: row.readAt !== null,
          createdAt: row.createdAt.toISOString(),
        };
      }),
    };
  }

  /** « Tout lire » : plus de pastille sur la cloche. */
  @Post('read')
  @HttpCode(HttpStatus.NO_CONTENT)
  async readAll(@CurrentUser() user: AuthUser): Promise<void> {
    await this.prisma.inboxItem.updateMany({
      where: { userId: user.id, readAt: null },
      data: { readAt: new Date() },
    });
  }
}
