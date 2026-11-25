import { Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser } from '../auth/decorators.js';
import { ApiZodBody, ApiZodResponse, ValidBody } from '../common/validation/zod.js';
import { OrderConversationDto, OrderMessageDto, SendMessageBody } from './messages.schemas.js';
import { MessagesService } from './messages.service.js';

@ApiTags('Messages')
@ApiBearerAuth()
@Controller('orders/:id/messages')
export class MessagesController {
  constructor(private readonly messages: MessagesService) {}

  /** Conversation de la commande (expéditeur, livreur, ou équipe en lecture). */
  @Get()
  @ApiZodResponse(OrderConversationDto)
  list(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<z.output<typeof OrderConversationDto>> {
    return this.messages.list(user, id);
  }

  /** Message à l'autre personne, tant que la course est en cours. */
  @Post()
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiZodBody(SendMessageBody)
  @ApiZodResponse(OrderMessageDto)
  send(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @ValidBody(SendMessageBody) body: z.output<typeof SendMessageBody>,
  ): Promise<z.output<typeof OrderMessageDto>> {
    return this.messages.send(user, id, body.body);
  }
}
