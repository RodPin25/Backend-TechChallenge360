// src/services/inventory.service.ts
import {
  inventoryRepository,
  type KardexAdjustmentResult,
  type KardexRecord,
  type ReservationRecord,
  type StockItemRecord,
} from '../repositories/inventory.repository';
import { BadRequestError } from '../core/errors';
import type { PaginatedResult } from '../core/types';
import type {
  ConsultKardexQuery,
  ListStockQuery,
  RegisterInventoryAdjustmentInput,
  ReleaseExpiredReservationsInput,
  ReleaseReservationInput,
  ReserveCartCheckoutInput,
  ReserveStockInput,
} from '../core/schemas/inventory.schema';

export class InventoryService {
  /**
   * Listado paginado de existencias físicas, reservadas, disponibles y conciliación con Kardex
   */
  public async listStock(query: ListStockQuery): Promise<PaginatedResult<StockItemRecord>> {
    return inventoryRepository.listarExistencias({
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      idCategoria: query.idCategoria,
      busqueda: query.busqueda,
      soloBajoStock: query.soloBajoStock,
      umbralBajoStock: query.umbralBajoStock,
    });
  }

  /**
   * Consulta paginada del historial del Kardex (RF-03)
   */
  public async consultKardex(query: ConsultKardexQuery): Promise<PaginatedResult<KardexRecord>> {
    return inventoryRepository.consultarKardex({
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      idVariante: query.idVariante,
      idProducto: query.idProducto,
      tipoMovimiento: query.tipoMovimiento,
      fechaInicio: query.fechaInicio,
      fechaFin: query.fechaFin,
    });
  }

  /**
   * Ajuste manual de almacén ('AJUSTE_ENTRADA' | 'AJUSTE_SALIDA') con trazabilidad en Kardex y Bitácora
   */
  public async registerAdjustment(
    idUsuario: number,
    input: RegisterInventoryAdjustmentInput,
  ): Promise<KardexAdjustmentResult> {
    return inventoryRepository.registrarAjuste({
      idUsuario,
      idVariante: input.idVariante,
      tipoMovimiento: input.tipoMovimiento,
      cantidad: input.cantidad,
      motivo: input.motivo,
    });
  }

  /**
   * Reserva temporal (TTL 15 min) de una variante específica con bloqueo pesimista
   */
  public async reserveStock(
    idUsuario: number | undefined,
    input: ReserveStockInput,
  ): Promise<ReservationRecord> {
    if (!idUsuario && !input.tokenSesion) {
      throw new BadRequestError(
        'Debe iniciar sesión o proporcionar un tokenSesion para reservar existencia.',
      );
    }

    return inventoryRepository.reservarExistencia({
      idVariante: input.idVariante,
      cantidad: input.cantidad,
      idUsuario,
      tokenSesion: input.tokenSesion,
    });
  }

  /**
   * Reserva temporal atómica (TTL 15 min) de todas las variantes del carrito activo al iniciar el checkout (RF-06)
   */
  public async reserveCartForCheckout(
    idUsuario: number | undefined,
    input: ReserveCartCheckoutInput,
  ): Promise<ReservationRecord[]> {
    if (!idUsuario && !input.tokenSesion) {
      throw new BadRequestError(
        'Debe iniciar sesión o proporcionar un tokenSesion para reservar el carrito.',
      );
    }

    return inventoryRepository.reservarCarritoCheckout({
      idCarrito: input.idCarrito,
      idUsuario,
      tokenSesion: input.tokenSesion,
    });
  }

  /**
   * Liberación manual de reservas de un cliente o sesión
   */
  public async releaseReservation(
    idUsuario: number | undefined,
    input: ReleaseReservationInput,
  ): Promise<{ ReservasLiberadas: number; FechaLiberacion: Date }> {
    if (!input.idReserva && !idUsuario && !input.tokenSesion) {
      throw new BadRequestError(
        'Debe especificar un idReserva, iniciar sesión o enviar tokenSesion para liberar reservas.',
      );
    }

    return inventoryRepository.liberarReserva({
      idReserva: input.idReserva,
      idUsuario,
      tokenSesion: input.tokenSesion,
    });
  }

  /**
   * Barrido administrativo/automático de reservas expiradas
   */
  public async releaseExpiredReservations(
    input: ReleaseExpiredReservationsInput,
  ): Promise<{ ReservasExpiradasLiberadas: number; FechaCorte: Date }> {
    return inventoryRepository.liberarReservasExpiradas(input.idVariante);
  }
}

export const inventoryService = new InventoryService();
