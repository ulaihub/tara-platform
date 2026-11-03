import 'dotenv/config';
import { randomInt, randomUUID } from 'node:crypto';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { App } from 'supertest/types.js';
import { AppModule } from '../../src/app.module.js';
import { configureApp } from '../../src/app.setup.js';
import { TokenService } from '../../src/auth/token.service.js';
import type { UserRole } from '../../src/generated/prisma/enums.js';
import { PrismaService } from '../../src/prisma/prisma.service.js';
import { type FakeSmsProvider, SMS_PROVIDER } from '../../src/sms/sms.provider.js';

// OSRM n'est pas disponible dans les tests : distance estimée à vol d'oiseau corrigée.
delete process.env['OSRM_URL'];

export interface TestContext {
  app: NestExpressApplication;
  http: App;
  prisma: PrismaService;
  sms: FakeSmsProvider;
  tokens: TokenService;
}

/**
 * Application complète pour les tests. `env` remplace des variables de configuration pour
 * cette instance seulement (ex. plafonds bas pour tester les limites).
 */
export async function createTestApp(env: Record<string, string> = {}): Promise<TestContext> {
  const saved = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  Object.assign(process.env, env);
  let app: NestExpressApplication;
  try {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication<NestExpressApplication>({
      logger: ['error'],
      rawBody: true,
    });
    configureApp(app);
    await app.init();
  } finally {
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
  return {
    app,
    http: app.getHttpServer(),
    prisma: app.get(PrismaService),
    sms: app.get<FakeSmsProvider>(SMS_PROVIDER),
    tokens: app.get(TokenService),
  };
}

/** Numéro de mobile camerounais aléatoire, pour isoler chaque test. */
export function randomPhone(): string {
  return `+2376${String(randomInt(0, 100_000_000)).padStart(8, '0')}`;
}

export function otpFrom(sms: FakeSmsProvider, phone: string): string {
  const text = sms.lastTo(phone)?.text ?? '';
  const code = /(\d{6})/.exec(text)?.[1];
  if (!code) throw new Error(`Aucun code SMS reçu pour ${phone}`);
  return code;
}

export interface SignedIn {
  userId: string;
  phone: string;
  accessToken: string;
  refreshToken: string;
  auth: { Authorization: string };
  /** Appareil de la session (connexion par SMS uniquement). */
  installationId?: string;
}

/** Parcours complet de connexion par SMS, création du compte comprise. */
export async function signIn(ctx: TestContext, phone = randomPhone()): Promise<SignedIn> {
  const challenge = await request(ctx.http).post('/v1/auth/otp').send({ phone }).expect(201);
  const installationId = randomUUID();
  const session = await request(ctx.http)
    .post('/v1/auth/otp/verify')
    .send({
      challengeId: challenge.body.challengeId,
      code: otpFrom(ctx.sms, phone),
      device: { installationId, platform: 'ANDROID' },
      termsVersion: '2026-11',
    })
    .expect(200);
  return {
    userId: session.body.user.id,
    phone,
    accessToken: session.body.accessToken,
    refreshToken: session.body.refreshToken,
    auth: { Authorization: `Bearer ${session.body.accessToken}` },
    installationId,
  };
}

/**
 * Compte de l'équipe Tara, créé directement en base, déjà enrôlé en double authentification,
 * avec une session dont le second facteur vient d'être vérifié.
 */
export async function staffUser(ctx: TestContext, roles: UserRole[]): Promise<SignedIn> {
  const phone = randomPhone();
  const now = new Date();
  const user = await ctx.prisma.user.create({
    data: {
      phone,
      roles,
      totpEnabledAt: new Date(now.getTime() - 60_000),
      totpSecretEnc: 'non-utilise',
    },
  });
  const session = await ctx.tokens.issueSession(user.id, null, undefined, now);
  return {
    userId: user.id,
    phone,
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    auth: { Authorization: `Bearer ${session.accessToken}` },
  };
}
