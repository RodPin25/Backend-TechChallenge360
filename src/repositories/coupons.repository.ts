// src/repositories/coupons.repository.ts
import { getPool, sql } from '../config/db';
import { mapSqlError } from '../core/errors';
import type { PaginatedResult } from '../core/types';

export interface CouponRecord {
  IDCupon: number;
  Codigo: string;
  TipoDescuento: string;
  ValorDescuento: number;
  MontoMinimoCompra: number;
  IDCategoria: number | null;
  NombreCategoria: string | null;
  FechaInicio: Date;
  FechaFin: Date;
  LimiteUsosTotal: number;
  UsosActuales: number;
  UsosRestantes?: number;
  LimiteUsosPorCliente: number;
  Activo: boolean;
  EstaVigente?: boolean;
}

export interface CouponUsageRecord {
  IDCuponUso: number;
  IDCupon: number;
  IDUsuario: number;
  NombreCliente: string;
  CorreoCliente: string;
  IDPedido: number;
  SubtotalPedido: number;
  MontoDescuento: number;
  TotalPedido: number;
  FechaUso: Date;
}

export interface CouponDetailResult {
  cupon: CouponRecord;
  historialUsos: CouponUsageRecord[];
}

export interface CouponCartValidationResult {
  IDCarrito: number;
  IDCupon: number;
  Codigo: string;
  TipoDescuento: string;
  ValorDescuento: number;
  MontoMinimoCompra: number;
  IDCategoria: number | null;
  EsValido: boolean;
  MensajeValidacion: string;
  SubtotalCarrito: number;
  SubtotalCategoriaElegible: number;
  MontoDescuento: number;
  TotalSinIVA: number;
  MontoIVA: number;
  TotalConDescuento: number;
}

export class CouponsRepository {
  /**
   * 1. dbo.SP_Cupones_Crear
   */
  public async crear(params: {
    idUsuario: number;
    codigo: string;
    tipoDescuento: string;
    valorDescuento: number;
    montoMinimoCompra: number;
    idCategoria?: number | null | undefined;
    fechaInicio: Date;
    fechaFin: Date;
    limiteUsosTotal: number;
    limiteUsosPorCliente: number;
  }): Promise<CouponRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('Codigo', sql.VarChar(30), params.codigo);
      request.input('TipoDescuento', sql.VarChar(20), params.tipoDescuento);
      request.input(
        'ValorDescuento',
        sql.Decimal(12, 2),
        Number(params.valorDescuento.toFixed(2)),
      );
      request.input(
        'MontoMinimoCompra',
        sql.Decimal(12, 2),
        Number(params.montoMinimoCompra.toFixed(2)),
      );
      request.input('IDCategoria', sql.Int, params.idCategoria ?? null);
      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin);
      request.input('LimiteUsosTotal', sql.Int, params.limiteUsosTotal);
      request.input('LimiteUsosPorCliente', sql.Int, params.limiteUsosPorCliente);

      const result = await request.execute<CouponRecord>('dbo.SP_Cupones_Crear');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el cupón creado.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 2. dbo.SP_Cupones_Actualizar
   */
  public async actualizar(params: {
    idUsuario: number;
    idCupon: number;
    codigo: string;
    tipoDescuento: string;
    valorDescuento: number;
    montoMinimoCompra: number;
    idCategoria?: number | null | undefined;
    fechaInicio: Date;
    fechaFin: Date;
    limiteUsosTotal: number;
    limiteUsosPorCliente: number;
    activo: boolean;
  }): Promise<CouponRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDCupon', sql.Int, params.idCupon);
      request.input('Codigo', sql.VarChar(30), params.codigo);
      request.input('TipoDescuento', sql.VarChar(20), params.tipoDescuento);
      request.input(
        'ValorDescuento',
        sql.Decimal(12, 2),
        Number(params.valorDescuento.toFixed(2)),
      );
      request.input(
        'MontoMinimoCompra',
        sql.Decimal(12, 2),
        Number(params.montoMinimoCompra.toFixed(2)),
      );
      request.input('IDCategoria', sql.Int, params.idCategoria ?? null);
      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin);
      request.input('LimiteUsosTotal', sql.Int, params.limiteUsosTotal);
      request.input('LimiteUsosPorCliente', sql.Int, params.limiteUsosPorCliente);
      request.input('Activo', sql.Bit, params.activo);

      const result = await request.execute<CouponRecord>('dbo.SP_Cupones_Actualizar');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el cupón actualizado.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 3. dbo.SP_Cupones_CambiarEstadoActivo
   */
  public async cambiarEstadoActivo(params: {
    idUsuario: number;
    idCupon: number;
    activo: boolean;
  }): Promise<{ IDCupon: number; Codigo: string; Activo: boolean }> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDCupon', sql.Int, params.idCupon);
      request.input('Activo', sql.Bit, params.activo);

      const result = await request.execute<{ IDCupon: number; Codigo: string; Activo: boolean }>(
        'dbo.SP_Cupones_CambiarEstadoActivo',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el estado actualizado del cupón.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 4. dbo.SP_Cupones_Listar
   */
  public async listar(params: {
    numeroPagina: number;
    tamanoPagina: number;
    activo?: boolean | undefined;
    soloVigentes: boolean;
    tipoDescuento?: string | undefined;
    busqueda?: string | undefined;
  }): Promise<PaginatedResult<CouponRecord>> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('Activo', sql.Bit, params.activo ?? null);
      request.input('SoloVigentes', sql.Bit, params.soloVigentes);
      request.input('TipoDescuento', sql.VarChar(20), params.tipoDescuento ?? null);
      request.input('Busqueda', sql.VarChar(30), params.busqueda ?? null);

      const result = await request.execute('dbo.SP_Cupones_Listar');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number }>,
        CouponRecord[],
      ];

      const totalRegistros = recordsets[0]?.[0]?.TotalRegistros ?? 0;
      const items = recordsets[1] ?? [];
      const totalPaginas = Math.ceil(totalRegistros / params.tamanoPagina);

      return {
        items,
        totalRegistros,
        numeroPagina: params.numeroPagina,
        tamanoPagina: params.tamanoPagina,
        totalPaginas,
      };
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 5. dbo.SP_Cupones_ObtenerPorID
   */
  public async obtenerPorID(idCupon: number): Promise<CouponDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDCupon', sql.Int, idCupon);

      const result = await request.execute('dbo.SP_Cupones_ObtenerPorID');
      const recordsets = result.recordsets as unknown as [CouponRecord[], CouponUsageRecord[]];

      const cupon = recordsets[0]?.[0];
      if (!cupon) {
        throw new Error('No se encontró el cupón solicitado.');
      }

      const historialUsos = recordsets[1] ?? [];
      return { cupon, historialUsos };
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 6. dbo.SP_Cupones_ValidarYAplicarEnCarrito
   */
  public async validarYAplicarEnCarrito(params: {
    codigo: string;
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
  }): Promise<CouponCartValidationResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('Codigo', sql.VarChar(30), params.codigo);
      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('TokenInvitado', sql.VarChar(100), params.tokenInvitado ?? null);

      const result = await request.execute<CouponCartValidationResult>(
        'dbo.SP_Cupones_ValidarYAplicarEnCarrito',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el resultado de validación del cupón.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }
}

export const couponsRepository = new CouponsRepository();
