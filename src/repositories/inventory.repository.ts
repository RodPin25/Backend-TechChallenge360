// src/repositories/inventory.repository.ts
import { getPool, sql } from '../config/db';
import { mapSqlError } from '../core/errors';
import type { PaginatedResult } from '../core/types';

export interface ReservationRecord {
  IDReserva: number;
  IDVariante: number;
  SKU: string;
  NombreVariante: string;
  IDUsuario?: number | null;
  TokenSesion?: string | null;
  CantidadReservada: number;
  FechaCreacion: Date;
  FechaExpiracion: Date;
  Estado: string;
  StockDisponibleRestante?: number;
}

export interface KardexAdjustmentResult {
  IDKardex: number;
  IDVariante: number;
  SKU: string;
  NombreVariante: string;
  TipoMovimiento: string;
  Cantidad: number;
  StockAnterior: number;
  StockActual: number;
  StockReservado: number;
  StockDisponible: number;
  IDUsuario: number;
  Motivo: string;
  FechaMovimiento: Date;
}

export interface KardexRecord {
  IDKardex: number;
  IDVariante: number;
  SKU: string;
  NombreVariante: string;
  IDProducto: number;
  NombreProducto: string;
  TipoMovimiento: string;
  Cantidad: number;
  StockAnterior: number;
  StockActual: number;
  IDPedido: number | null;
  IDDevolucion: number | null;
  IDUsuario: number;
  UsuarioResponsable: string;
  CorreoResponsable: string;
  Motivo: string;
  FechaMovimiento: Date;
}

export interface StockItemRecord {
  IDVariante: number;
  SKU: string;
  NombreVariante: string;
  IDProducto: number;
  NombreProducto: string;
  IDCategoria: number;
  NombreCategoria: string;
  Precio: number;
  StockFisico: number;
  StockReservado: number;
  StockDisponible: number;
  SumaMovimientosKardex: number;
  CuadraConKardex: boolean;
  VarianteActiva: boolean;
  ProductoActivo: boolean;
}

export class InventoryRepository {
  /**
   * 1. dbo.SP_Inventario_LiberarReservasExpiradas
   */
  public async liberarReservasExpiradas(
    idVariante?: number | undefined,
  ): Promise<{ ReservasExpiradasLiberadas: number; FechaCorte: Date }> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDVariante', sql.Int, idVariante ?? null);

      const result = await request.execute<{
        ReservasExpiradasLiberadas: number;
        FechaCorte: Date;
      }>('dbo.SP_Inventario_LiberarReservasExpiradas');

      return (
        result.recordset?.[0] ?? {
          ReservasExpiradasLiberadas: 0,
          FechaCorte: new Date(),
        }
      );
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 2. dbo.SP_Inventario_ReservarExistencia
   */
  public async reservarExistencia(params: {
    idVariante: number;
    cantidad: number;
    idUsuario?: number | undefined;
    tokenSesion?: string | undefined;
  }): Promise<ReservationRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('Cantidad', sql.Int, params.cantidad);
      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('TokenSesion', sql.VarChar(100), params.tokenSesion ?? null);

      const result = await request.execute<ReservationRecord>(
        'dbo.SP_Inventario_ReservarExistencia',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el detalle de la reserva creada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 3. dbo.SP_Inventario_ReservarCarritoCheckout
   */
  public async reservarCarritoCheckout(params: {
    idCarrito: number;
    idUsuario?: number | undefined;
    tokenSesion?: string | undefined;
  }): Promise<ReservationRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDCarrito', sql.Int, params.idCarrito);
      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('TokenSesion', sql.VarChar(100), params.tokenSesion ?? null);

      const result = await request.execute<ReservationRecord>(
        'dbo.SP_Inventario_ReservarCarritoCheckout',
      );

      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 4. dbo.SP_Inventario_LiberarReserva
   */
  public async liberarReserva(params: {
    idReserva?: number | undefined;
    idUsuario?: number | undefined;
    tokenSesion?: string | undefined;
  }): Promise<{ ReservasLiberadas: number; FechaLiberacion: Date }> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDReserva', sql.BigInt, params.idReserva ?? null);
      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('TokenSesion', sql.VarChar(100), params.tokenSesion ?? null);

      const result = await request.execute<{
        ReservasLiberadas: number;
        FechaLiberacion: Date;
      }>('dbo.SP_Inventario_LiberarReserva');

      return (
        result.recordset?.[0] ?? {
          ReservasLiberadas: 0,
          FechaLiberacion: new Date(),
        }
      );
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 5. dbo.SP_Inventario_RegistrarAjuste
   */
  public async registrarAjuste(params: {
    idUsuario: number;
    idVariante: number;
    tipoMovimiento: string;
    cantidad: number;
    motivo: string;
  }): Promise<KardexAdjustmentResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('TipoMovimiento', sql.VarChar(25), params.tipoMovimiento);
      request.input('Cantidad', sql.Int, params.cantidad);
      request.input('Motivo', sql.NVarChar(250), params.motivo);

      const result = await request.execute<KardexAdjustmentResult>(
        'dbo.SP_Inventario_RegistrarAjuste',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el registro de ajuste en Kardex.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 6. dbo.SP_Inventario_ConsultarKardex
   */
  public async consultarKardex(params: {
    numeroPagina: number;
    tamanoPagina: number;
    idVariante?: number | undefined;
    idProducto?: number | undefined;
    tipoMovimiento?: string | undefined;
    fechaInicio?: Date | undefined;
    fechaFin?: Date | undefined;
  }): Promise<PaginatedResult<KardexRecord>> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('IDVariante', sql.Int, params.idVariante ?? null);
      request.input('IDProducto', sql.Int, params.idProducto ?? null);
      request.input('TipoMovimiento', sql.VarChar(25), params.tipoMovimiento ?? null);
      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio ?? null);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin ?? null);

      const result = await request.execute('dbo.SP_Inventario_ConsultarKardex');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number }>,
        KardexRecord[],
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
   * 7. dbo.SP_Inventario_ListarExistencias
   */
  public async listarExistencias(params: {
    numeroPagina: number;
    tamanoPagina: number;
    idCategoria?: number | undefined;
    busqueda?: string | undefined;
    soloBajoStock: boolean;
    umbralBajoStock: number;
  }): Promise<PaginatedResult<StockItemRecord>> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('IDCategoria', sql.Int, params.idCategoria ?? null);
      request.input('Busqueda', sql.NVarChar(150), params.busqueda ?? null);
      request.input('SoloBajoStock', sql.Bit, params.soloBajoStock);
      request.input('UmbralBajoStock', sql.Int, params.umbralBajoStock);

      const result = await request.execute('dbo.SP_Inventario_ListarExistencias');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number }>,
        StockItemRecord[],
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
}

export const inventoryRepository = new InventoryRepository();
