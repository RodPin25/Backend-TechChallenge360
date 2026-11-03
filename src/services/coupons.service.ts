// src/services/coupons.service.ts
import {
  couponsRepository,
  type CouponCartValidationResult,
  type CouponDetailResult,
  type CouponRecord,
} from '../repositories/coupons.repository';
import { BadRequestError } from '../core/errors';
import type { PaginatedResult } from '../core/types';
import type {
  CreateCouponInput,
  ListCouponsQuery,
  UpdateCouponInput,
  UpdateCouponStatusInput,
  ValidateCouponInCartInput,
} from '../core/schemas/coupons.schema';

export class CouponsService {
  public async listCoupons(query: ListCouponsQuery): Promise<PaginatedResult<CouponRecord>> {
    return couponsRepository.listar({
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      activo: query.activo,
      soloVigentes: query.soloVigentes,
      tipoDescuento: query.tipoDescuento,
      busqueda: query.busqueda,
    });
  }

  public async getCouponById(idCupon: number): Promise<CouponDetailResult> {
    return couponsRepository.obtenerPorID(idCupon);
  }

  public async createCoupon(
    idUsuario: number,
    input: CreateCouponInput,
  ): Promise<CouponRecord> {
    return couponsRepository.crear({
      idUsuario,
      codigo: input.codigo,
      tipoDescuento: input.tipoDescuento,
      valorDescuento: input.valorDescuento,
      montoMinimoCompra: input.montoMinimoCompra,
      idCategoria: input.idCategoria,
      fechaInicio: input.fechaInicio,
      fechaFin: input.fechaFin,
      limiteUsosTotal: input.limiteUsosTotal,
      limiteUsosPorCliente: input.limiteUsosPorCliente,
    });
  }

  public async updateCoupon(
    idUsuario: number,
    idCupon: number,
    input: UpdateCouponInput,
  ): Promise<CouponRecord> {
    return couponsRepository.actualizar({
      idUsuario,
      idCupon,
      codigo: input.codigo,
      tipoDescuento: input.tipoDescuento,
      valorDescuento: input.valorDescuento,
      montoMinimoCompra: input.montoMinimoCompra,
      idCategoria: input.idCategoria,
      fechaInicio: input.fechaInicio,
      fechaFin: input.fechaFin,
      limiteUsosTotal: input.limiteUsosTotal,
      limiteUsosPorCliente: input.limiteUsosPorCliente,
      activo: input.activo,
    });
  }

  public async updateCouponStatus(
    idUsuario: number,
    idCupon: number,
    input: UpdateCouponStatusInput,
  ): Promise<{ IDCupon: number; Codigo: string; Activo: boolean }> {
    return couponsRepository.cambiarEstadoActivo({
      idUsuario,
      idCupon,
      activo: input.activo,
    });
  }

  public async validateAndApplyInCart(
    idUsuario: number | undefined,
    input: ValidateCouponInCartInput,
  ): Promise<CouponCartValidationResult> {
    if (!idUsuario && !input.tokenInvitado) {
      throw new BadRequestError(
        'Debe iniciar sesión o enviar el token de invitado para validar el cupón en el carrito.',
      );
    }

    return couponsRepository.validarYAplicarEnCarrito({
      codigo: input.codigo,
      idUsuario,
      tokenInvitado: input.tokenInvitado,
    });
  }
}

export const couponsService = new CouponsService();
