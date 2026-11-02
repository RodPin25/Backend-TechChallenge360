// src/middlewares/errorHandler.ts
import type { Request, Response, NextFunction } from 'express';
import { AppError, NotFoundError } from '../core/errors';
import { ERROR_CODES } from '../core/constants';
import type { ApiResponse } from '../core/types';
import { env } from '../config/env';

/**
 * Middleware para rutas inexistentes (404 Not Found).
 */
export const notFoundHandler = (req: Request, _res: Response, next: NextFunction): void => {
  next(new NotFoundError(`Ruta no encontrada: ${req.method} ${req.originalUrl}`));
};

/**
 * Middleware global para captura y formateo uniforme de errores HTTP.
 */
export const errorHandler = (
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void => {
  if (err instanceof AppError) {
    const responseBody: ApiResponse<never> = {
      success: false,
      error: {
        code: err.code,
        message: err.message,
        ...(err.details !== undefined ? { details: err.details } : {}),
      },
    };

    res.status(err.statusCode).json(responseBody);
    return;
  }

  console.error('[UNHANDLED ERROR]:', err);

  const responseBody: ApiResponse<never> = {
    success: false,
    error: {
      code: ERROR_CODES.INTERNAL_ERROR,
      message:
        env.NODE_ENV === 'development' && err instanceof Error
          ? err.message
          : 'Ocurrió un error interno en el servidor.',
    },
  };

  res.status(500).json(responseBody);
};
