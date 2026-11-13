import {
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
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../auth/auth.types.js';
import { CurrentUser, Roles } from '../auth/decorators.js';
import {
  ApiZodBody,
  ApiZodQuery,
  ApiZodResponse,
  ValidBody,
  ValidQuery,
} from '../common/validation/zod.js';
import {
  AuditListQuery,
  AuditPageDto,
  TeamMemberBody,
  TeamMemberDto,
  TeamRolesBody,
} from './team.schemas.js';
import { TeamService } from './team.service.js';

@ApiTags('Back-office · équipe et audit')
@ApiBearerAuth()
@Roles('ADMIN')
@Controller('admin')
export class TeamController {
  constructor(private readonly team: TeamService) {}

  /** Membres de l'équipe, leurs rôles et leur double authentification (H8). */
  @Get('team')
  @ApiZodResponse(z.array(TeamMemberDto))
  members(): Promise<z.output<typeof TeamMemberDto>[]> {
    return this.team.members();
  }

  /** Donne l'accès au back-office à un numéro (nouveau compte ou compte existant). */
  @Post('team')
  @ApiZodBody(TeamMemberBody)
  @ApiZodResponse(TeamMemberDto, HttpStatus.CREATED)
  add(
    @CurrentUser() user: AuthUser,
    @ValidBody(TeamMemberBody) body: z.output<typeof TeamMemberBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof TeamMemberDto>> {
    return this.team.add(user, body, request);
  }

  @Put('team/:userId/roles')
  @ApiZodBody(TeamRolesBody)
  @ApiZodResponse(TeamMemberDto)
  setRoles(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
    @ValidBody(TeamRolesBody) body: z.output<typeof TeamRolesBody>,
    @Req() request: Request,
  ): Promise<z.output<typeof TeamMemberDto>> {
    return this.team.setRoles(user, userId, body.roles, request);
  }

  @Delete('team/:userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Req() request: Request,
  ): Promise<void> {
    return this.team.remove(user, userId, request);
  }

  /** Journal des actions sensibles, les plus récentes d'abord (H8). */
  @Get('audit-log')
  @ApiZodQuery(AuditListQuery)
  @ApiZodResponse(AuditPageDto)
  auditLog(
    @ValidQuery(AuditListQuery) query: z.output<typeof AuditListQuery>,
  ): Promise<z.output<typeof AuditPageDto>> {
    return this.team.auditLog(query);
  }
}
