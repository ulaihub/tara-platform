import { Controller, Get, Inject } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { z } from 'zod';
import { Public } from '../auth/decorators.js';
import { ENV } from '../config/config.module.js';
import type { Env } from '../config/env.js';
import { ApiZodResponse } from '../common/validation/zod.js';

export const AppConfigDto = z
  .object({
    country: z.object({ code: z.string().length(2), dialCode: z.string(), currency: z.string() }),
    /** Ligne du support (« Pas reçu de SMS ? », aide), null si non configurée. */
    supportPhone: z.string().nullable(),
    mobileMoneyOperators: z.array(z.object({ code: z.string(), name: z.string() })),
    /**
     * Frais Mobile Money payés par le client, en points de base du montant encaissé : l'app
     * affiche frais = arrondi supérieur de montant × taux / (10 000 − taux).
     */
    mobileMoneyFeeBps: z.int(),
    /** Attente du livreur au point d'enlèvement : minutes gratuites, puis montant par tranche. */
    waiting: z.object({
      freeMinutes: z.int(),
      stepMinutes: z.int(),
      feePerStep: z.int(),
      maxFee: z.int(),
    }),
  })
  .meta({ id: 'AppConfig' });

/**
 * Réglages publics de l'app expéditeur, lus avant même la connexion (écran du code SMS) et
 * gardés sur le téléphone : pays, ligne du support, opérateurs Mobile Money.
 */
@ApiTags('Réglages')
@Public()
@Throttle({ default: { limit: 60, ttl: 60_000 } })
@Controller('public/config')
export class PublicConfigController {
  constructor(@Inject(ENV) private readonly env: Env) {}

  @Get()
  @ApiZodResponse(AppConfigDto)
  config(): z.output<typeof AppConfigDto> {
    return {
      country: { code: 'CM', dialCode: '+237', currency: 'XAF' },
      supportPhone: this.env.SUPPORT_PHONE ?? null,
      mobileMoneyOperators: [
        { code: 'MTN', name: 'MTN MoMo' },
        { code: 'ORANGE', name: 'Orange Money' },
      ],
      mobileMoneyFeeBps: this.env.MOBILE_MONEY_FEE_BPS,
      waiting: {
        freeMinutes: this.env.WAITING_FREE_MINUTES,
        stepMinutes: this.env.WAITING_STEP_MINUTES,
        feePerStep: this.env.WAITING_FEE_PER_STEP,
        maxFee: this.env.WAITING_FEE_MAX,
      },
    };
  }
}
