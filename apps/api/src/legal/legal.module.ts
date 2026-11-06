import { Module } from '@nestjs/common';
import { LegalController, TermsController } from './legal.controller.js';
import { LegalService } from './legal.service.js';

/** Conditions d'utilisation, notice destinataire et confidentialité : textes et acceptation. */
@Module({
  controllers: [LegalController, TermsController],
  providers: [LegalService],
  exports: [LegalService],
})
export class LegalModule {}
