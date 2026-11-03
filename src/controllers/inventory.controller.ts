// src/controllers/inventory.controller.ts
import type { Request, Response, NextFunction } from 'express';
import { inventoryService } from '../services/inventory.service';
import { UnauthorizedError } from '../core/errors';
import type {
  ConsultKardexQuery,
  ListStockQuery,
  RegisterInventoryAdjustmentInput,
  ReleaseExpiredReservationsInput,
  ReleaseReservationInput,
  ReserveCartCheckoutInput,
  ReserveStockInput,
} from '../core/schemas/inventory.schema';

export class InventoryController {
  private getAuthenticatedUserId(req: Request): number {
    if (!req.user?.idUsuario) {
      throw new UnauthorizedError('Usuario no autenticado.');
    }
    return req.user.idUsuario;
  }

  private resolveSessionToken(req: Request, bodyToken?: string): string | undefined {
    const headerToken = req.headers['x-guest-token'] ?? req.headers['x-session-token'];
    if (typeof headerToken === 'string' && headerToken.trim().length > 0) {
      return headerToken.trim();
    }
    return bodyToken;
  }

  public listStock = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const query = req.query as unknown as ListStockQuery;
      const data = await inventoryService.listStock(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public consultKardex = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const query = req.query as unknown as ConsultKardexQuery;
      const data = await inventoryService.consultKardex(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public registerAdjustment = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as RegisterInventoryAdjustmentInput;
      const data = await inventoryService.registerAdjustment(idUsuario, body);

      res.status(201).json({
        success: true,
        data,
        message: 'Ajuste de inventario registrado exitosamente en el Kardex.',
      });
    } catch (error) {
      next(error);
    }
  };

  public reserveStock = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const body = req.body as ReserveStockInput;
      const tokenSesion = this.resolveSessionToken(req, body.tokenSesion);

      const data = await inventoryService.reserveStock(req.user?.idUsuario, {
        ...body,
        tokenSesion,
      });

      res.status(201).json({
        success: true,
        data,
        message: 'Existencia reservada temporalmente durante 15 minutos.',
      });
    } catch (error) {
      next(error);
    }
  };

  public reserveCartCheckout = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const body = req.body as ReserveCartCheckoutInput;
      const tokenSesion = this.resolveSessionToken(req, body.tokenSesion);

      const data = await inventoryService.reserveCartForCheckout(req.user?.idUsuario, {
        ...body,
        tokenSesion,
      });

      res.status(200).json({
        success: true,
        data,
        message: 'Existencias del carrito reservadas durante 15 minutos para el checkout.',
      });
    } catch (error) {
      next(error);
    }
  };

  public releaseReservation = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const body = (req.body ?? {}) as ReleaseReservationInput;
      const tokenSesion = this.resolveSessionToken(req, body.tokenSesion);

      const data = await inventoryService.releaseReservation(req.user?.idUsuario, {
        ...body,
        tokenSesion,
      });

      res.status(200).json({
        success: true,
        data,
        message: 'Reservas temporales liberadas exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public releaseExpiredReservations = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const body = (req.body ?? {}) as ReleaseExpiredReservationsInput;
      const data = await inventoryService.releaseExpiredReservations(body);

      res.status(200).json({
        success: true,
        data,
        message: 'Barrido de reservas expiradas ejecutado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };
}

export const inventoryController = new InventoryController();
