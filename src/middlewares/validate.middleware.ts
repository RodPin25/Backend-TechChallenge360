// src/middlewares/validate.middleware.ts
import type { Request, Response, NextFunction } from 'express';
import { z, type ZodType } from 'zod';
import { BadRequestError } from '../core/errors';
import { ERROR_CODES } from '../core/constants';

export interface RequestValidationSchemas {
  body?: ZodType;
  query?: ZodType;
  params?: ZodType;
}

/**
 * Middleware genérico para validar req.body, req.query y req.params con Zod.
 */
export const validateRequest = (schemas: RequestValidationSchemas) => {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      if (schemas.body) {
        const parsedBody = schemas.body.safeParse(req.body);
        if (!parsedBody.success) {
          throw new BadRequestError(
            'Error de validación en el cuerpo de la solicitud.',
            ERROR_CODES.VALIDATION_ERROR,
            z.treeifyError(parsedBody.error),
          );
        }
        req.body = parsedBody.data;
      }

      if (schemas.query) {
        const parsedQuery = schemas.query.safeParse(req.query);
        if (!parsedQuery.success) {
          throw new BadRequestError(
            'Error de validación en los parámetros de consulta (query).',
            ERROR_CODES.VALIDATION_ERROR,
            z.treeifyError(parsedQuery.error),
          );
        }
        Object.assign(req.query, parsedQuery.data);
      }

      if (schemas.params) {
        const parsedParams = schemas.params.safeParse(req.params);
        if (!parsedParams.success) {
          throw new BadRequestError(
            'Error de validación en los parámetros de ruta (params).',
            ERROR_CODES.VALIDATION_ERROR,
            z.treeifyError(parsedParams.error),
          );
        }
        Object.assign(req.params, parsedParams.data);
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};
