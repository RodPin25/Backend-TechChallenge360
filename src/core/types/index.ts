// src/core/types/index.ts
import type { RoleId, RoleName } from '../constants';

export interface ApiErrorDetail {
  code: string;
  message: string;
  details?: unknown;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  message?: string;
  error?: ApiErrorDetail;
}

export interface PaginatedResult<T> {
  items: T[];
  totalRegistros: number;
  numeroPagina: number;
  tamanoPagina: number;
  totalPaginas: number;
}

export interface JwtUserPayload {
  idUsuario: number;
  idRol: RoleId | number;
  nombreRol: RoleName | string;
  correo: string;
}

export interface RefreshTokenPayload {
  idUsuario: number;
  jti: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: JwtUserPayload;
    }
  }
}
