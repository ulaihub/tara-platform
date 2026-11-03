import { HttpStatus } from '@nestjs/common';
import type { ErrorCode } from './error-codes.js';

export type ErrorParams = Record<string, string | number>;

/**
 * Erreur métier attendue : code stable, statut HTTP, paramètres du message.
 * Toute erreur qui n'est pas une AppError (ni une erreur HTTP de Nest) devient une 500.
 */
export class AppError extends Error {
  constructor(
    readonly code: ErrorCode,
    readonly status: HttpStatus,
    readonly params: ErrorParams = {},
    readonly details?: unknown,
  ) {
    super(code);
    this.name = 'AppError';
  }

  static badRequest(code: ErrorCode, params?: ErrorParams, details?: unknown): AppError {
    return new AppError(code, HttpStatus.BAD_REQUEST, params, details);
  }
  static unprocessable(code: ErrorCode, params?: ErrorParams, details?: unknown): AppError {
    return new AppError(code, HttpStatus.UNPROCESSABLE_ENTITY, params, details);
  }
  static notFound(code: ErrorCode = 'NOT_FOUND'): AppError {
    return new AppError(code, HttpStatus.NOT_FOUND);
  }
  static conflict(code: ErrorCode, params?: ErrorParams): AppError {
    return new AppError(code, HttpStatus.CONFLICT, params);
  }
  static forbidden(code: ErrorCode = 'FORBIDDEN'): AppError {
    return new AppError(code, HttpStatus.FORBIDDEN);
  }
  static unauthorized(code: ErrorCode = 'UNAUTHENTICATED'): AppError {
    return new AppError(code, HttpStatus.UNAUTHORIZED);
  }
  static tooMany(code: ErrorCode, params?: ErrorParams): AppError {
    return new AppError(code, HttpStatus.TOO_MANY_REQUESTS, params);
  }
}
