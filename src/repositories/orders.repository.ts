// src/repositories/orders.repository.ts
import { getPool, sql } from '../config/db';
import { mapSqlError } from '../core/errors';
import type { PaginatedResult } from '../core/types';

export interface OrderHeaderRecord {
  IDPedido: number;
  IDUsuario: number;
  NombreCliente: string;
  CorreoCliente: string;
  TelefonoCliente?: string | null;
  IDDireccion?: number;
  DireccionEntregaTexto: string;
  IDCupon: number | null;
  CodigoCupon: string | null;
  TipoDescuento?: string | null;
  IdempotencyKey?: string;
  EstadoPedido: string;
  Subtotal: number;
  MontoDescuento: number;
  TotalSinIVA?: number;
  MontoIVA: number;
  Total: number;
  FechaCreacion: Date;
  FueRespuestaIdempotente?: boolean;
  TotalLineas?: number;
  TotalUnidades?: number;
}

export interface OrderLineRecord {
  IDPedidoDetalle: number;
  IDPedido: number;
  IDVariante: number;
  SKU: string;
  NombreVariante: string;
  IDProducto: number;
  NombreProducto: string;
  IDCategoria: number;
  NombreCategoria: string;
  Cantidad: number;
  PrecioUnitarioCongelado: number;
  DescuentoAplicado: number;
  SubtotalLinea: number;
  CantidadYaDevuelta: number;
  CantidadDisponibleDevolver: number;
}

export interface OrderPaymentRecord {
  IDPago: number;
  IDPedido: number;
  MetodoPago: string;
  TransaccionId: string;
  Monto: number;
  Estado: string;
  FechaPago: Date;
}

export interface OrderStatusHistoryRecord {
  IDHistorialEstado: number;
  IDPedido: number;
  IDUsuario: number;
  UsuarioResponsable: string;
  RolResponsable: string;
  EstadoAnterior: string;
  EstadoNuevo: string;
  FechaHora: Date;
}

export interface OrderDetailResult {
  pedido: OrderHeaderRecord;
  lineas: OrderLineRecord[];
  pagos: OrderPaymentRecord[];
  historialEstados: OrderStatusHistoryRecord[];
}

export interface ReturnHeaderRecord {
  IDDevolucion: number;
  IDPedido: number;
  EstadoPedido?: string;
  IDCliente: number;
  NombreCliente: string;
  CorreoCliente: string;
  IDUsuarioRegistra?: number;
  UsuarioRegistra?: string;
  Motivo: string;
  Estado: string;
  FechaSolicitud: Date;
  TotalUnidadesDevueltas: number;
  MontoReintegroConIVA: number;
  MontoReintegroSinIVA?: number;
  MontoReintegroIVA?: number;
}

export interface ReturnLineRecord {
  IDDevolucionDetalle: number;
  IDDevolucion: number;
  IDVariante: number;
  SKU: string;
  NombreVariante: string;
  IDProducto: number;
  NombreProducto: string;
  CantidadCompradaOriginal: number;
  PrecioUnitarioCongelado: number;
  SubtotalLineaOriginal: number;
  CantidadDevuelta: number;
  MontoLineaDevuelta: number;
}

export interface ReturnDetailResult {
  devolucion: ReturnHeaderRecord;
  lineas: ReturnLineRecord[];
}

export class OrdersRepository {
  private mapOrderDetailResult(result: { recordsets: unknown }): OrderDetailResult {
    const recordsets = result.recordsets as [
      OrderHeaderRecord[],
      OrderLineRecord[],
      OrderPaymentRecord[],
      OrderStatusHistoryRecord[],
    ];

    const pedido = recordsets[0]?.[0];
    if (!pedido) {
      throw new Error('No se encontró el detalle del pedido.');
    }

    return {
      pedido,
      lineas: recordsets[1] ?? [],
      pagos: recordsets[2] ?? [],
      historialEstados: recordsets[3] ?? [],
    };
  }

  private mapReturnDetailResult(result: { recordsets: unknown }): ReturnDetailResult {
    const recordsets = result.recordsets as [ReturnHeaderRecord[], ReturnLineRecord[]];

    const devolucion = recordsets[0]?.[0];
    if (!devolucion) {
      throw new Error('No se encontró el detalle de la devolución.');
    }

    return {
      devolucion,
      lineas: recordsets[1] ?? [],
    };
  }

  /**
   * 1. dbo.SP_Pedidos_ObtenerDetalle
   */
  public async obtenerDetallePedido(
    idPedido: number,
    idUsuarioSolicitante: number,
  ): Promise<OrderDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDPedido', sql.Int, idPedido);
      request.input('IDUsuarioSolicitante', sql.Int, idUsuarioSolicitante);
      request.input('FueRespuestaIdempotente', sql.Bit, false);

      const result = await request.execute('dbo.SP_Pedidos_ObtenerDetalle');
      return this.mapOrderDetailResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 2. dbo.SP_Pedidos_CrearCheckout
   */
  public async crearCheckout(params: {
    idUsuario: number;
    idDireccion: number;
    idempotencyKey: string;
    codigoCupon?: string | undefined;
    metodoPago: string;
    transaccionId?: string | undefined;
  }): Promise<OrderDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDDireccion', sql.Int, params.idDireccion);
      request.input('IdempotencyKey', sql.VarChar(64), params.idempotencyKey);
      request.input('CodigoCupon', sql.VarChar(30), params.codigoCupon ?? null);
      request.input('MetodoPago', sql.VarChar(30), params.metodoPago);
      request.input('TransaccionId', sql.VarChar(100), params.transaccionId ?? null);

      const result = await request.execute('dbo.SP_Pedidos_CrearCheckout');
      return this.mapOrderDetailResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 3. dbo.SP_Pedidos_CambiarEstado
   */
  public async cambiarEstadoPedido(params: {
    idPedido: number;
    idUsuario: number;
    estadoNuevo: string;
    motivo?: string | undefined;
  }): Promise<OrderDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDPedido', sql.Int, params.idPedido);
      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('EstadoNuevo', sql.VarChar(30), params.estadoNuevo);
      request.input('Motivo', sql.NVarChar(250), params.motivo ?? null);

      const result = await request.execute('dbo.SP_Pedidos_CambiarEstado');
      return this.mapOrderDetailResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 4. dbo.SP_Pedidos_Listar
   */
  public async listarPedidos(params: {
    idUsuarioSolicitante: number;
    numeroPagina: number;
    tamanoPagina: number;
    estadoPedido?: string | undefined;
    idClienteFiltro?: number | undefined;
    fechaInicio?: Date | undefined;
    fechaFin?: Date | undefined;
  }): Promise<PaginatedResult<OrderHeaderRecord>> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuarioSolicitante', sql.Int, params.idUsuarioSolicitante);
      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('EstadoPedido', sql.VarChar(30), params.estadoPedido ?? null);
      request.input('IDClienteFiltro', sql.Int, params.idClienteFiltro ?? null);
      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio ?? null);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin ?? null);

      const result = await request.execute('dbo.SP_Pedidos_Listar');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number }>,
        OrderHeaderRecord[],
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

  // ==========================================================================
  // DEVOLUCIONES (09_sp_devoluciones.sql)
  // ==========================================================================

  /**
   * 5. dbo.SP_Devoluciones_ObtenerDetalle
   */
  public async obtenerDetalleDevolucion(
    idDevolucion: number,
    idUsuarioSolicitante: number,
  ): Promise<ReturnDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDDevolucion', sql.Int, idDevolucion);
      request.input('IDUsuarioSolicitante', sql.Int, idUsuarioSolicitante);

      const result = await request.execute('dbo.SP_Devoluciones_ObtenerDetalle');
      return this.mapReturnDetailResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 6. dbo.SP_Devoluciones_Solicitar
   */
  public async solicitarDevolucion(params: {
    idPedido: number;
    idUsuario: number;
    motivo: string;
    itemsJSON: string;
  }): Promise<ReturnDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDPedido', sql.Int, params.idPedido);
      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('Motivo', sql.NVarChar(250), params.motivo);
      request.input('ItemsJSON', sql.NVarChar(sql.MAX), params.itemsJSON);

      const result = await request.execute('dbo.SP_Devoluciones_Solicitar');
      return this.mapReturnDetailResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 7. dbo.SP_Devoluciones_Resolver
   */
  public async resolverDevolucion(params: {
    idDevolucion: number;
    idUsuario: number;
    nuevoEstado: string;
    observacion?: string | undefined;
  }): Promise<ReturnDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDDevolucion', sql.Int, params.idDevolucion);
      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('NuevoEstado', sql.VarChar(20), params.nuevoEstado);
      request.input('Observacion', sql.NVarChar(250), params.observacion ?? null);

      const result = await request.execute('dbo.SP_Devoluciones_Resolver');
      return this.mapReturnDetailResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 8. dbo.SP_Devoluciones_Listar
   */
  public async listarDevoluciones(params: {
    idUsuarioSolicitante: number;
    numeroPagina: number;
    tamanoPagina: number;
    estado?: string | undefined;
    idPedido?: number | undefined;
    idClienteFiltro?: number | undefined;
    fechaInicio?: Date | undefined;
    fechaFin?: Date | undefined;
  }): Promise<PaginatedResult<ReturnHeaderRecord>> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuarioSolicitante', sql.Int, params.idUsuarioSolicitante);
      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('Estado', sql.VarChar(20), params.estado ?? null);
      request.input('IDPedido', sql.Int, params.idPedido ?? null);
      request.input('IDClienteFiltro', sql.Int, params.idClienteFiltro ?? null);
      request.input('FechaInicio', sql.DateTime2(0), params.fechaInicio ?? null);
      request.input('FechaFin', sql.DateTime2(0), params.fechaFin ?? null);

      const result = await request.execute('dbo.SP_Devoluciones_Listar');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number }>,
        ReturnHeaderRecord[],
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

export const ordersRepository = new OrdersRepository();
