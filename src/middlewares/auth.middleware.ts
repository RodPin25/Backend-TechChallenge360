// src/middlewares/auth.middleware.ts
import type { Request, Response, NextFunction } from 'express';
import jwt, { TokenExpiredError } from 'jsonwebtoken';
import { env } from '../config/env';
import { UnauthorizedError } from '../core/errors';
import { ERROR_CODES } from '../core/constants';
import type { JwtUserPayload } from '../core/types';

/**
 * Extrae el token Bearer del header Authorization.
 */
function extractBearerToken(authHeader: string | undefined): string | null {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  const token = authHeader.slice(7).trim();
  return token.length > 0 ? token : null;
}

/**
 * Middleware obligatorio de autenticación JWT.
 * Devuelve 401 si no hay token, si es inválido o si ha expirado (RF-01).
 */
export const authenticateJWT = (req: Request, _res: Response, next: NextFunction): void => {
  try {
    const token = extractBearerToken(req.headers.authorization);

    if (!token) {
      throw new UnauthorizedError('Token de autenticación no proporcionado.');
    }

    const decoded = jwt.verify(token, env.JWT_SECRET) as JwtUserPayload;

    req.user = {
      idUsuario: decoded.idUsuario,
      idRol: decoded.idRol,
      nombreRol: decoded.nombreRol,
      correo: decoded.correo,
    };

    next();
  } catch (error) {
    if (error instanceof TokenExpiredError) {
      next(new UnauthorizedError('El token de acceso ha expirado.', ERROR_CODES.TOKEN_EXPIRED));
      return;
    }
    if (error instanceof UnauthorizedError) {
      next(error);
      return;
    }
    next(new UnauthorizedError('Token de acceso inválido.'));
  }
};

/**
 * Middleware de autenticación opcional (útil para rutas como el Carrito que soportan invitado o usuario autenticado).
 */
export const optionalAuthenticateJWT = (req: Request, _res: Response, next: NextFunction): void => {
  const token = extractBearerToken(req.headers.authorization);
  if (!token) {
    next();
    return;
  }

  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as JwtUserPayload;
    req.user = {
      idUsuario: decoded.idUsuario,
      idRol: decoded.idRol,
      nombreRol: decoded.nombreRol,
      correo: decoded.correo,
    };
    next();
  } catch (error) {
    if (error instanceof TokenExpiredError) {
      next(new UnauthorizedError('El token de acceso ha expirado.', ERROR_CODES.TOKEN_EXPIRED));
      return;
    }
    next(new UnauthorizedError('Token de acceso inválido.'));
  }
};
