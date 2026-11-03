// src/services/cart.service.ts
import { cartRepository, type CartDetailResult } from '../repositories/cart.repository';
import { BadRequestError } from '../core/errors';
import type { UpsertCartItemInput } from '../core/schemas/cart.schema';

export class CartService {
  private ensureActorProvided(idUsuario?: number, tokenInvitado?: string): void {
    if (!idUsuario && !tokenInvitado) {
      throw new BadRequestError(
        'Debe iniciar sesión o enviar el token de invitado (header x-guest-token o query/body tokenInvitado).',
      );
    }
  }

  public async getCart(params: {
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
    codigoCupon?: string | undefined;
  }): Promise<CartDetailResult> {
    this.ensureActorProvided(params.idUsuario, params.tokenInvitado);
    return cartRepository.obtenerDetalle(params);
  }

  public async addOrUpdateItem(params: {
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
    input: UpsertCartItemInput;
  }): Promise<CartDetailResult> {
    this.ensureActorProvided(params.idUsuario, params.tokenInvitado);

    return cartRepository.agregarOModificarItem({
      idVariante: params.input.idVariante,
      cantidad: params.input.cantidad,
      idUsuario: params.idUsuario,
      tokenInvitado: params.tokenInvitado,
      modoOperacion: params.input.modoOperacion,
    });
  }

  public async setItemQuantity(params: {
    idVariante: number;
    cantidad: number;
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
  }): Promise<CartDetailResult> {
    this.ensureActorProvided(params.idUsuario, params.tokenInvitado);

    return cartRepository.agregarOModificarItem({
      idVariante: params.idVariante,
      cantidad: params.cantidad,
      idUsuario: params.idUsuario,
      tokenInvitado: params.tokenInvitado,
      modoOperacion: 'FIJAR',
    });
  }

  public async removeItem(params: {
    idVariante: number;
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
  }): Promise<CartDetailResult> {
    this.ensureActorProvided(params.idUsuario, params.tokenInvitado);
    return cartRepository.eliminarItem(params);
  }

  public async clearCart(params: {
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
  }): Promise<CartDetailResult> {
    this.ensureActorProvided(params.idUsuario, params.tokenInvitado);
    return cartRepository.vaciar(params);
  }

  public async mergeGuestCart(idUsuario: number, tokenInvitado: string): Promise<CartDetailResult> {
    return cartRepository.fusionarInvitadoAUsuario({
      idUsuario,
      tokenInvitado,
    });
  }
}

export const cartService = new CartService();
