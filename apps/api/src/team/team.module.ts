import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { TeamController } from './team.controller.js';
import { TeamService } from './team.service.js';

/** Équipe et journal d'audit (H8). */
@Module({
  imports: [AuthModule, AuditModule],
  controllers: [TeamController],
  providers: [TeamService],
})
export class TeamModule {}
