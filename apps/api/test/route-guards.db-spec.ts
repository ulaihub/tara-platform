import { RequestMethod } from '@nestjs/common';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { DiscoveryService, MetadataScanner, Reflector } from '@nestjs/core';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { isStaffRole } from '../src/auth/auth.types.js';
import { IS_PUBLIC, REQUIRED_ROLES } from '../src/auth/decorators.js';
import type { UserRole } from '../src/generated/prisma/enums.js';
import { createTestApp, type TestContext } from './helpers/app.js';

interface Route {
  route: string;
  roles: UserRole[];
  isPublic: boolean;
}

const join = (...parts: string[]) =>
  parts
    .flatMap((part) => part.split('/'))
    .filter(Boolean)
    .join('/');

/** Toutes les routes HTTP de l'API, avec les rôles exigés et leur caractère public. */
function routes(ctx: TestContext): Route[] {
  const discovery = ctx.app.get(DiscoveryService);
  const scanner = ctx.app.get(MetadataScanner);
  const reflector = ctx.app.get(Reflector);
  const out: Route[] = [];
  for (const wrapper of discovery.getControllers()) {
    const type = wrapper.metatype as (abstract new (...args: never[]) => unknown) | null;
    if (!type) continue;
    const base = (Reflect.getMetadata(PATH_METADATA, type) as string | string[] | undefined) ?? '';
    const prototype = type.prototype as Record<string, (...args: unknown[]) => unknown>;
    for (const name of scanner.getAllMethodNames(prototype)) {
      const handler = prototype[name];
      if (!handler) continue;
      const path = Reflect.getMetadata(PATH_METADATA, handler) as string | string[] | undefined;
      if (path === undefined) continue;
      const method = RequestMethod[Reflect.getMetadata(METHOD_METADATA, handler) as number];
      const targets = [handler, type];
      for (const prefix of [base].flat()) {
        for (const suffix of [path].flat()) {
          out.push({
            route: `${method} /${join(prefix, suffix)}`,
            roles:
              reflector.getAllAndOverride<UserRole[] | undefined>(REQUIRED_ROLES, targets) ?? [],
            isPublic: reflector.getAllAndOverride<boolean | undefined>(IS_PUBLIC, targets) === true,
          });
        }
      }
    }
  }
  return out.sort((a, b) => a.route.localeCompare(b.route));
}

/**
 * Routes ouvertes sans connexion, revues une à une (revue de sécurité de la phase 7). Toute
 * nouvelle route publique doit être ajoutée ici en connaissance de cause : jeton aléatoire
 * de 128 bits, signature du prestataire, ou information sans donnée personnelle.
 */
const PUBLIC_ROUTES = [
  'GET /health',
  'GET /legal/:document',
  'GET /public/config',
  'GET /public/location-links/:token',
  'GET /public/receipts/:code',
  'GET /public/tracking/:token',
  'GET /webhooks/payments/:provider',
  'GET /webhooks/whatsapp',
  'POST /auth/logout',
  'POST /auth/otp',
  'POST /auth/otp/verify',
  'POST /auth/refresh',
  'POST /public/location-links/:token',
  'POST /public/tracking/:token/delivery-code',
  'POST /public/tracking/:token/response',
  'POST /webhooks/payments/:provider',
  'POST /webhooks/whatsapp',
];

describe('Garde des routes (revue de sécurité)', () => {
  let ctx: TestContext;
  let all: Route[];

  beforeAll(async () => {
    ctx = await createTestApp();
    all = routes(ctx);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('trouve les routes de l’API', () => {
    expect(all.length).toBeGreaterThan(150);
  });

  it('réserve chaque route du back-office (/admin) à des rôles de l’équipe', () => {
    const admin = all.filter((route) => /^\w+ \/admin(\/|$)/.test(route.route));
    expect(admin.length).toBeGreaterThan(40);
    const open = admin.filter(
      (route) => route.isPublic || route.roles.length === 0 || !route.roles.every(isStaffRole),
    );
    expect(open.map((route) => route.route)).toEqual([]);
  });

  it('n’ouvre sans connexion que les routes revues', () => {
    expect(all.filter((route) => route.isPublic).map((route) => route.route)).toEqual(
      PUBLIC_ROUTES,
    );
  });
});
