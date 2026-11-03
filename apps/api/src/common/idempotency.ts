import { ApiHeader } from '@nestjs/swagger';
import { z } from 'zod';
import { AppError } from './errors/app-error.js';

const IdempotencyKey = z.string().regex(/^[A-Za-z0-9_-]{8,100}$/);

/** Valeur de l'en-tête Idempotency-Key, vérifiée ; undefined si absent. */
export function idempotencyKey(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  if (!IdempotencyKey.safeParse(value).success) {
    throw AppError.badRequest('VALIDATION_FAILED', {}, [
      { path: 'Idempotency-Key', message: 'format invalide' },
    ]);
  }
  return value;
}

/** En-tête obligatoire : toute opération qui déplace de l'argent doit pouvoir être rejouée. */
export function requiredIdempotencyKey(value: string | undefined): string {
  const key = idempotencyKey(value);
  if (!key) {
    throw AppError.badRequest('VALIDATION_FAILED', {}, [
      { path: 'Idempotency-Key', message: 'requis' },
    ]);
  }
  return key;
}

export const IdempotencyHeader = (required: boolean, description: string): MethodDecorator =>
  ApiHeader({ name: 'Idempotency-Key', required, description });
