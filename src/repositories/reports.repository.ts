// src/repositories/reports.repository.ts
import { getPool, sql } from '../config/db';
import { mapSqlError } from '../core/errors';
import type { PaginatedResult } from '../core/types';

export interface DashboardKpisRecord {
  FechaInicio: Date;
  FechaFin: Date;
  NumeroPedidosCompletados: number;
  PedidosCancelados: number;
  UnidadesNetasVendidas: number;
  VentaBrutaGTQ: number;
  MontoDevolucionesGTQ: number;
  VentaNetaGTQ: number;
  VentaNetaSinIVAGTQ: number;
  MontoIVANetoGTQ: number;
  TicketPromedioGTQ: number;
  TotalCarritosAbandonados: number;
  MontoCarritosAbandonadosGTQ: number;
}

export interface SalesByPeriodRecord {
  EtiquetaPeriodo: string;
  FechaReferencia: Date;
  NumeroPedidos: number;
  UnidadesNetasVendidas: number;
  MontoDevolucionesGTQ: number;
  VentaNetaGTQ: number;
  TicketPromedioGTQ: number;
}

export interface SalesByCategoryRecord {
  IDCategoria: number;
  NombreCategoria: string;
  NumeroPedidos: number;
  UnidadesNetasVendidas: number;
  MontoDevolucionesGTQ: number;
  VentaNetaGTQ: number;
  PorcentajeParticipacion: number;
}

export interface TopProductRecord {
  IDProducto: number;
  NombreProducto: string;
  IDCategoria: number;
  NombreCategoria: string;
  NumeroPedidos: number;
  UnidadesBrutasVendidas: number;
  UnidadesDevueltas: number;
  UnidadesNetasVendidas: number;
  IngresoNetoGTQ: number;
}

export interface AbandonedCartRecord {
  IDCarrito: number;
  IDUsuario: number | null;
  NombreCliente: string | null;
  CorreoCliente: string | null;
  TokenInvitado: string | null;
  EstadoCarrito: string;
  FechaCreacion: Date;
  UltimaActividad: Date;
  MinutosInactividad: number;
  HorasInactividad: number;
  TotalLineas: number;
  TotalUnidades: number;
  MontoEstimadoGTQ: number;
}

export interface AbandonedCartsPaginatedResult extends PaginatedResult<AbandonedCartRecord> {
  montoPotencialTotalGTQ: number;
}

export interface AuditLogRecord {
  IDBitacora: number;
  FechaHora: Date;
  Modulo: string;
  Accion: string;
  IDRegistroAfectado: string;
  IDUsuario: number | null;
  NombreUsuario: string;
  CorreoUsuario: string | null;
  RolUsuario: string | null;
  ValorAnterior: string | null;
  ValorNuevo: string;
}

export class ReportsRepository {
  /**
   * 1. dbo.SP_Dashboard_ObtenerResumenKPIs
   */
  public async obtenerResumenKPIs(params: {
    fechaInicio?: Date | undefined;
    fechaFin?: Date | undefined;
    minutosAbandono: number;
  }): Promise<DashboardKpisRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio ?? null);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin ?? null);
      request.input('MinutosAbandono', sql.Int, params.minutosAbandono);

      const result = await request.execute<DashboardKpisRecord>(
        'dbo.SP_Dashboard_ObtenerResumenKPIs',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se pudieron obtener los KPIs del dashboard.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 2. dbo.SP_Dashboard_VentasPorPeriodo
   */
  public async obtenerVentasPorPeriodo(params: {
    agrupacion: 'DIA' | 'SEMANA' | 'MES';
    fechaInicio?: Date | undefined;
    fechaFin?: Date | undefined;
  }): Promise<SalesByPeriodRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('Agrupacion', sql.VarChar(15), params.agrupacion);
      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio ?? null);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin ?? null);

      const result = await request.execute<SalesByPeriodRecord>(
        'dbo.SP_Dashboard_VentasPorPeriodo',
      );

      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 3. dbo.SP_Dashboard_VentasPorCategoria
   */
  public async obtenerVentasPorCategoria(params: {
    fechaInicio?: Date | undefined;
    fechaFin?: Date | undefined;
  }): Promise<SalesByCategoryRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio ?? null);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin ?? null);

      const result = await request.execute<SalesByCategoryRecord>(
        'dbo.SP_Dashboard_VentasPorCategoria',
      );

      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 4. dbo.SP_Dashboard_TopProductosMasVendidos
   */
  public async obtenerTopProductosMasVendidos(params: {
    fechaInicio?: Date | undefined;
    fechaFin?: Date | undefined;
    topN: number;
  }): Promise<TopProductRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio ?? null);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin ?? null);
      request.input('TopN', sql.Int, params.topN);

      const result = await request.execute<TopProductRecord>(
        'dbo.SP_Dashboard_TopProductosMasVendidos',
      );

      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 5. dbo.SP_Dashboard_ListarCarritosAbandonados
   */
  public async listarCarritosAbandonados(params: {
    numeroPagina: number;
    tamanoPagina: number;
    minutosInactividad: number;
  }): Promise<AbandonedCartsPaginatedResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('MinutosInactividad', sql.Int, params.minutosInactividad);

      const result = await request.execute('dbo.SP_Dashboard_ListarCarritosAbandonados');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number; MontoPotencialTotalGTQ: number }>,
        AbandonedCartRecord[],
      ];

      const summary = recordsets[0]?.[0];
      const totalRegistros = summary?.TotalRegistros ?? 0;
      const montoPotencialTotalGTQ = summary?.MontoPotencialTotalGTQ ?? 0;
      const items = recordsets[1] ?? [];
      const totalPaginas = Math.ceil(totalRegistros / params.tamanoPagina);

      return {
        items,
        totalRegistros,
        numeroPagina: params.numeroPagina,
        tamanoPagina: params.tamanoPagina,
        totalPaginas,
        montoPotencialTotalGTQ,
      };
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 6. dbo.SP_Auditoria_ConsultarBitacora
   */
  public async consultarBitacora(params: {
    numeroPagina: number;
    tamanoPagina: number;
    modulo?: string | undefined;
    accion?: string | undefined;
    idUsuario?: number | undefined;
    fechaInicio?: Date | undefined;
    fechaFin?: Date | undefined;
  }): Promise<PaginatedResult<AuditLogRecord>> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('Modulo', sql.VarChar(50), params.modulo ?? null);
      request.input('Accion', sql.VarChar(20), params.accion ?? null);
      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio ?? null);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin ?? null);

      const result = await request.execute('dbo.SP_Auditoria_ConsultarBitacora');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number }>,
        AuditLogRecord[],
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

export const reportsRepository = new ReportsRepository();
