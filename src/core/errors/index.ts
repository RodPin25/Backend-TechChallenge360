// src/core/errors/index.ts
import { ERROR_CODES, type ErrorCode } from '../constants';

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: ErrorCode | string;
  public readonly details?: unknown;
  public readonly isOperational: boolean;

  constructor(
    message: string,
    statusCode: number = 500,
    code: ErrorCode | string = ERROR_CODES.INTERNAL_ERROR,
    details?: unknown,
    isOperational: boolean = true,
  ) {
    super(message);
    Object.setPrototypeOf(this, new.target.prototype);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = isOperational;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class BadRequestError extends AppError {
  constructor(
    message: string = 'Solicitud inválida.',
    code: ErrorCode | string = ERROR_CODES.BAD_REQUEST,
    details?: unknown,
  ) {
    super(message, 400, code, details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(
    message: string = 'No autorizado. Inicie sesión para continuar.',
    code: ErrorCode | string = ERROR_CODES.UNAUTHORIZED,
  ) {
    super(message, 401, code);
  }
}

export class ForbiddenError extends AppError {
  constructor(
    message: string = 'No tiene permisos para acceder a este recurso.',
    code: ErrorCode | string = ERROR_CODES.FORBIDDEN,
  ) {
    super(message, 403, code);
  }
}

export class NotFoundError extends AppError {
  constructor(
    message: string = 'El recurso solicitado no fue encontrado.',
    code: ErrorCode | string = ERROR_CODES.NOT_FOUND,
  ) {
    super(message, 404, code);
  }
}

export class ConflictError extends AppError {
  constructor(
    message: string = 'Conflicto con el estado actual del recurso.',
    code: ErrorCode | string = ERROR_CODES.CONFLICT,
    details?: unknown,
  ) {
    super(message, 409, code, details);
  }
}

export class DatabaseError extends AppError {
  constructor(
    message: string = 'Error al procesar la operación en la base de datos.',
    details?: unknown,
  ) {
    super(message, 500, ERROR_CODES.DATABASE_ERROR, details);
  }
}

interface SqlServerErrorShape {
  number?: number;
  message?: string;
  procName?: string;
}

/**
 * Traduce errores lanzados desde SQL Server (incluyendo ;THROW 500XX) a instancias de AppError.
 */
export function mapSqlError(error: unknown): AppError {
  if (error instanceof AppError) {
    return error;
  }

  const sqlErr = error as SqlServerErrorShape;
  const errNum = typeof sqlErr?.number === 'number' ? sqlErr.number : 0;
  const errMsg =
    typeof sqlErr?.message === 'string' && sqlErr.message.trim().length > 0
      ? sqlErr.message
      : 'Error en la operación de base de datos.';

  // Errores personalizados de negocio en T-SQL (50000 - 50999)
  if (errNum >= 50000 && errNum < 51000) {
    const lowerMsg = errMsg.toLowerCase();

    if (lowerMsg.includes('no existe') || lowerMsg.includes('no fue encontrad')) {
      return new NotFoundError(errMsg);
    }

    if (lowerMsg.includes('no pertenece al usuario') || lowerMsg.includes('no tiene permiso')) {
      return new ForbiddenError(errMsg);
    }

    if (lowerMsg.includes('desactivad') || lowerMsg.includes('inactiv')) {
      return new ForbiddenError(errMsg);
    }

    if (lowerMsg.includes('existencia') || lowerMsg.includes('stock')) {
      return new ConflictError(errMsg, ERROR_CODES.INSUFFICIENT_STOCK);
    }

    if (lowerMsg.includes('cupón') || lowerMsg.includes('cupon')) {
      return new BadRequestError(errMsg, ERROR_CODES.COUPON_INVALID);
    }

    if (lowerMsg.includes('transición') || lowerMsg.includes('transicion')) {
      return new ConflictError(errMsg, ERROR_CODES.INVALID_STATE_TRANSITION);
    }

    if (lowerMsg.includes('ya se encuentra registrado') || lowerMsg.includes('duplicad') || lowerMsg.includes('ya existe')) {
      return new ConflictError(errMsg);
    }

    return new BadRequestError(errMsg);
  }

  // Violación de restricción UNIQUE en SQL Server (2601, 2627)
  if (errNum === 2601 || errNum === 2627) {
    return new ConflictError('El registro ya existe o infringe una restricción de unicidad.');
  }

  // Violación de llave foránea o CHECK (547)
  if (errNum === 547) {
    return new BadRequestError('Los datos proporcionados infringen las reglas de integridad.');
  }

  return new DatabaseError('Ocurrió un error interno al consultar la base de datos.');
}
