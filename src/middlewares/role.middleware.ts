// src/middlewares/role.middleware.ts
import type { Request, Response, NextFunction } from 'express';
import { ForbiddenError, UnauthorizedError } from '../core/errors';
import type { RoleId, RoleName } from '../core/constants';

/**
 * Middleware de control de acceso basado en roles (RBAC).
 * Acepta IDs de rol (ej. ROLES.ADMIN) o nombres de rol (ej. ROLE_NAMES.ADMIN) para máxima compatibilidad.
 * Devuelve 401 si no hay usuario autenticado, o 403 si el rol no tiene permisos (RF-01).
 */
export const requireRoles = (...allowedRoles: Array<RoleId | RoleName>) => {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      next(new UnauthorizedError('Se requiere iniciar sesión para acceder a este recurso.'));
      return;
    }

    const hasPermission = allowedRoles.some((role) => {
      if (typeof role === 'number') {
        return req.user?.idRol === role;
      }
      return req.user?.nombreRol.toLowerCase() === role.toLowerCase();
    });

    if (!hasPermission) {
      next(new ForbiddenError('No tiene los permisos necesarios para realizar esta acción.'));
      return;
    }

    next();
  };
};
