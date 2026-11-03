// src/controllers/cart.controller.ts
import type { Request, Response, NextFunction } from 'express';
import { cartService } from '../services/cart.service';
import { UnauthorizedError } from '../core/errors';
import type {
  GetCartQuery,
  GuestTokenOptionalInput,
  MergeGuestCartInput,
  UpdateCartItemQuantityInput,
  UpsertCartItemInput,
} from '../core/schemas/cart.schema';

export class CartController {
  private getAuthenticatedUserId(req: Request): number {
    if (!req.user?.idUsuario) {
      throw new UnauthorizedError('Usuario no autenticado.');
    }
    return req.user.idUsuario;
  }

  private resolveGuestToken(req: Request, explicitToken?: string): string | undefined {
    const headerToken = req.headers['x-guest-token'] ?? req.headers['x-session-token'];
    if (typeof headerToken === 'string' && headerToken.trim().length > 0) {
      return headerToken.trim();
    }
    if (explicitToken && explicitToken.trim().length > 0) {
      return explicitToken.trim();
    }
    const queryToken = req.query.tokenInvitado;
    if (typeof queryToken === 'string' && queryToken.trim().length > 0) {
      return queryToken.trim();
    }
    return undefined;
  }

  public getCart = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const query = req.query as unknown as GetCartQuery;
      const tokenInvitado = this.resolveGuestToken(req, query.tokenInvitado);

      const data = await cartService.getCart({
        idUsuario: req.user?.idUsuario,
        tokenInvitado,
        codigoCupon: query.codigoCupon,
      });

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public addOrUpdateItem = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const body = req.body as UpsertCartItemInput;
      const tokenInvitado = this.resolveGuestToken(req, body.tokenInvitado);

      const data = await cartService.addOrUpdateItem({
        idUsuario: req.user?.idUsuario,
        tokenInvitado,
        input: body,
      });

      res.status(200).json({
        success: true,
        data,
        message: 'Producto actualizado en el carrito exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public setItemQuantity = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idVariante = Number(req.params.idVariante);
      const body = req.body as UpdateCartItemQuantityInput;
      const tokenInvitado = this.resolveGuestToken(req, body.tokenInvitado);

      const data = await cartService.setItemQuantity({
        idVariante,
        cantidad: body.cantidad,
        idUsuario: req.user?.idUsuario,
        tokenInvitado,
      });

      res.status(200).json({
        success: true,
        data,
        message: 'Cantidad actualizada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public removeItem = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idVariante = Number(req.params.idVariante);
      const body = (req.body ?? {}) as GuestTokenOptionalInput;
      const tokenInvitado = this.resolveGuestToken(req, body.tokenInvitado);

      const data = await cartService.removeItem({
        idVariante,
        idUsuario: req.user?.idUsuario,
        tokenInvitado,
      });

      res.status(200).json({
        success: true,
        data,
        message: 'Producto eliminado del carrito exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public clearCart = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const body = (req.body ?? {}) as GuestTokenOptionalInput;
      const tokenInvitado = this.resolveGuestToken(req, body.tokenInvitado);

      const data = await cartService.clearCart({
        idUsuario: req.user?.idUsuario,
        tokenInvitado,
      });

      res.status(200).json({
        success: true,
        data,
        message: 'Carrito vaciado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public mergeGuestCart = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as MergeGuestCartInput;

      const data = await cartService.mergeGuestCart(idUsuario, body.tokenInvitado);

      res.status(200).json({
        success: true,
        data,
        message: 'Carrito de invitado fusionado exitosamente con la cuenta del cliente.',
      });
    } catch (error) {
      next(error);
    }
  };
}

export const cartController = new CartController();
