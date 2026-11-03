// src/services/orders.service.ts
import {
  ordersRepository,
  type OrderDetailResult,
  type OrderHeaderRecord,
  type ReturnDetailResult,
  type ReturnHeaderRecord,
} from '../repositories/orders.repository';
import { BadRequestError } from '../core/errors';
import type { PaginatedResult } from '../core/types';
import type {
  ChangeOrderStatusInput,
  CheckoutOrderInput,
  ListOrdersQuery,
  ListReturnsQuery,
  RequestReturnInput,
  ResolveReturnInput,
} from '../core/schemas/orders.schema';

export class OrdersService {
  // ==========================================================================
  // 1. CHECKOUT Y PEDIDOS (RF-06, RF-07)
  // ==========================================================================

  public async createCheckout(
    idUsuario: number,
    input: CheckoutOrderInput,
    headerIdempotencyKey?: string,
  ): Promise<OrderDetailResult> {
    const finalIdempotencyKey = (headerIdempotencyKey ?? input.idempotencyKey ?? '').trim();

    if (!finalIdempotencyKey) {
      throw new BadRequestError(
        'La llave de idempotencia (header Idempotency-Key o campo idempotencyKey) es obligatoria para procesar el checkout.',
      );
    }

    return ordersRepository.crearCheckout({
      idUsuario,
      idDireccion: input.idDireccion,
      idempotencyKey: finalIdempotencyKey,
      codigoCupon: input.codigoCupon,
      metodoPago: input.metodoPago,
      transaccionId: input.transaccionId,
    });
  }

  public async getOrderDetail(
    idPedido: number,
    idUsuarioSolicitante: number,
  ): Promise<OrderDetailResult> {
    return ordersRepository.obtenerDetallePedido(idPedido, idUsuarioSolicitante);
  }

  public async listOrders(
    idUsuarioSolicitante: number,
    query: ListOrdersQuery,
  ): Promise<PaginatedResult<OrderHeaderRecord>> {
    return ordersRepository.listarPedidos({
      idUsuarioSolicitante,
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      estadoPedido: query.estadoPedido,
      idClienteFiltro: query.idCliente,
      fechaInicio: query.fechaInicio,
      fechaFin: query.fechaFin,
    });
  }

  public async changeOrderStatus(
    idPedido: number,
    idUsuario: number,
    input: ChangeOrderStatusInput,
  ): Promise<OrderDetailResult> {
    return ordersRepository.cambiarEstadoPedido({
      idPedido,
      idUsuario,
      estadoNuevo: input.estadoNuevo,
      motivo: input.motivo,
    });
  }

  // ==========================================================================
  // 2. DEVOLUCIONES (RF-07, RF-03)
  // ==========================================================================

  public async requestReturn(
    idUsuario: number,
    input: RequestReturnInput,
  ): Promise<ReturnDetailResult> {
    // Formatear con las llaves PascalCase exactas que espera OPENJSON en SP_Devoluciones_Solicitar
    const normalizedItems = input.items.map((item) => ({
      IDVariante: item.idVariante,
      Cantidad: item.cantidad,
    }));

    return ordersRepository.solicitarDevolucion({
      idPedido: input.idPedido,
      idUsuario,
      motivo: input.motivo,
      itemsJSON: JSON.stringify(normalizedItems),
    });
  }

  public async resolveReturn(
    idDevolucion: number,
    idUsuario: number,
    input: ResolveReturnInput,
  ): Promise<ReturnDetailResult> {
    return ordersRepository.resolverDevolucion({
      idDevolucion,
      idUsuario,
      nuevoEstado: input.nuevoEstado,
      observacion: input.observacion,
    });
  }

  public async getReturnDetail(
    idDevolucion: number,
    idUsuarioSolicitante: number,
  ): Promise<ReturnDetailResult> {
    return ordersRepository.obtenerDetalleDevolucion(idDevolucion, idUsuarioSolicitante);
  }

  public async listReturns(
    idUsuarioSolicitante: number,
    query: ListReturnsQuery,
  ): Promise<PaginatedResult<ReturnHeaderRecord>> {
    return ordersRepository.listarDevoluciones({
      idUsuarioSolicitante,
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      estado: query.estado,
      idPedido: query.idPedido,
      idClienteFiltro: query.idCliente,
      fechaInicio: query.fechaInicio,
      fechaFin: query.fechaFin,
    });
  }
}

export const ordersService = new OrdersService();
