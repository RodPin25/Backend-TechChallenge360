// src/controllers/coupons.controller.ts
import type { Request, Response, NextFunction } from 'express';
import { couponsService } from '../services/coupons.service';
import { UnauthorizedError } from '../core/errors';
import type {
  CreateCouponInput,
  ListCouponsQuery,
  UpdateCouponInput,
  UpdateCouponStatusInput,
  ValidateCouponInCartInput,
} from '../core/schemas/coupons.schema';

export class CouponsController {
  private getAuthenticatedUserId(req: Request): number {
    if (!req.user?.idUsuario) {
      throw new UnauthorizedError('Usuario no autenticado.');
    }
    return req.user.idUsuario;
  }

  private resolveGuestToken(req: Request, bodyToken?: string): string | undefined {
    const headerToken = req.headers['x-guest-token'] ?? req.headers['x-session-token'];
    if (typeof headerToken === 'string' && headerToken.trim().length > 0) {
      return headerToken.trim();
    }
    return bodyToken;
  }

  public listCoupons = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const query = req.query as unknown as ListCouponsQuery;
      const data = await couponsService.listCoupons(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public getCouponById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idCupon = Number(req.params.idCupon);
      const data = await couponsService.getCouponById(idCupon);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public createCoupon = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as CreateCouponInput;
      const data = await couponsService.createCoupon(idUsuario, body);

      res.status(201).json({
        success: true,
        data,
        message: 'Cupón creado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public updateCoupon = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idCupon = Number(req.params.idCupon);
      const body = req.body as UpdateCouponInput;

      const data = await couponsService.updateCoupon(idUsuario, idCupon, body);

      res.status(200).json({
        success: true,
        data,
        message: 'Cupón actualizado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public updateCouponStatus = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idCupon = Number(req.params.idCupon);
      const body = req.body as UpdateCouponStatusInput;

      const data = await couponsService.updateCouponStatus(idUsuario, idCupon, body);

      res.status(200).json({
        success: true,
        data,
        message: body.activo ? 'Cupón activado exitosamente.' : 'Cupón desactivado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public validateInCart = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const body = req.body as ValidateCouponInCartInput;
      const tokenInvitado = this.resolveGuestToken(req, body.tokenInvitado);

      const data = await couponsService.validateAndApplyInCart(req.user?.idUsuario, {
        codigo: body.codigo,
        tokenInvitado,
      });

      res.status(200).json({
        success: true,
        data,
        message: data.MensajeValidacion,
      });
    } catch (error) {
      next(error);
    }
  };
}

export const couponsController = new CouponsController();
