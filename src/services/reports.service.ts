// src/services/reports.service.ts
import {
  reportsRepository,
  type AbandonedCartsPaginatedResult,
  type AuditLogRecord,
  type DashboardKpisRecord,
  type SalesByCategoryRecord,
  type SalesByPeriodRecord,
  type TopProductRecord,
} from '../repositories/reports.repository';
import type { PaginatedResult } from '../core/types';
import type {
  AbandonedCartsQuery,
  ConsultAuditLogQuery,
  DashboardKpisQuery,
  SalesByCategoryQuery,
  SalesByPeriodQuery,
  TopProductsQuery,
} from '../core/schemas/reports.schema';

export class ReportsService {
  public async getDashboardKpis(query: DashboardKpisQuery): Promise<DashboardKpisRecord> {
    return reportsRepository.obtenerResumenKPIs({
      fechaInicio: query.fechaInicio,
      fechaFin: query.fechaFin,
      minutosAbandono: query.minutosAbandono,
    });
  }

  public async getSalesByPeriod(query: SalesByPeriodQuery): Promise<SalesByPeriodRecord[]> {
    return reportsRepository.obtenerVentasPorPeriodo({
      agrupacion: query.agrupacion,
      fechaInicio: query.fechaInicio,
      fechaFin: query.fechaFin,
    });
  }

  public async getSalesByCategory(query: SalesByCategoryQuery): Promise<SalesByCategoryRecord[]> {
    return reportsRepository.obtenerVentasPorCategoria({
      fechaInicio: query.fechaInicio,
      fechaFin: query.fechaFin,
    });
  }

  public async getTopProducts(query: TopProductsQuery): Promise<TopProductRecord[]> {
    return reportsRepository.obtenerTopProductosMasVendidos({
      fechaInicio: query.fechaInicio,
      fechaFin: query.fechaFin,
      topN: query.topN,
    });
  }

  public async listAbandonedCarts(
    query: AbandonedCartsQuery,
  ): Promise<AbandonedCartsPaginatedResult> {
    return reportsRepository.listarCarritosAbandonados({
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      minutosInactividad: query.minutosInactividad,
    });
  }

  public async consultAuditLog(
    query: ConsultAuditLogQuery,
  ): Promise<PaginatedResult<AuditLogRecord>> {
    return reportsRepository.consultarBitacora({
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      modulo: query.modulo,
      accion: query.accion,
      idUsuario: query.idUsuario,
      fechaInicio: query.fechaInicio,
      fechaFin: query.fechaFin,
    });
  }
}

export const reportsService = new ReportsService();
