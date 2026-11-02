import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { interpolate, resolveLocale } from '../i18n/locale.js';
import { AppError } from './app-error.js';
import { ERROR_MESSAGES, type ErrorCode } from './error-codes.js';
import type { AuthenticatedRequest } from '../../auth/auth.types.js';

export interface ErrorBody {
  error: { code: ErrorCode; message: string; details?: unknown; requestId?: string };
}

const HTTP_STATUS_CODES: Partial<Record<number, ErrorCode>> = {
  [HttpStatus.BAD_REQUEST]: 'VALIDATION_FAILED',
  [HttpStatus.UNAUTHORIZED]: 'UNAUTHENTICATED',
  [HttpStatus.FORBIDDEN]: 'FORBIDDEN',
  [HttpStatus.NOT_FOUND]: 'NOT_FOUND',
  [HttpStatus.PAYLOAD_TOO_LARGE]: 'PAYLOAD_TOO_LARGE',
  [HttpStatus.TOO_MANY_REQUESTS]: 'RATE_LIMITED',
};

/**
 * Format d'erreur unique : `{ error: { code, message, details? } }`, message dans la langue
 * de l'utilisateur. Les erreurs inattendues sont journalisées et masquées (500).
 */
@Catch()
export class AppExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('Errors');

  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const request = http.getRequest<Request & Partial<AuthenticatedRequest>>();
    const response = http.getResponse<Response>();
    const locale = resolveLocale(request.headers['accept-language'], request.user?.locale);

    const requestId = (request as { id?: string }).id;
    let status: number;
    let code: ErrorCode;
    let params: Record<string, string | number> = {};
    let details: unknown;

    if (exception instanceof AppError) {
      status = exception.status;
      code = exception.code;
      params = exception.params;
      details = exception.details;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      code = HTTP_STATUS_CODES[status] ?? (status >= 500 ? 'INTERNAL_ERROR' : 'VALIDATION_FAILED');
    } else {
      status = HttpStatus.INTERNAL_SERVER_ERROR;
      code = 'INTERNAL_ERROR';
      this.logger.error(
        `${request.method} ${request.url} [${requestId ?? '-'}]`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    const body: ErrorBody = {
      error: {
        code,
        message: interpolate(ERROR_MESSAGES[code][locale], params),
        ...(details === undefined ? {} : { details }),
        ...(requestId ? { requestId } : {}),
      },
    };
    response.status(status).json(body);
  }
}
