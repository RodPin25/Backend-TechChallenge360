// src/controllers/orders.controller.ts
import type { Request, Response, NextFunction } from 'express';
import { ordersService } from '../services/orders.service';
import { UnauthorizedError } from '../core/errors';
import type {
  ChangeOrderStatusInput,
  CheckoutOrderInput,
  ListOrdersQuery,
  ListReturnsQuery,
  RequestReturnInput,
  ResolveReturnInput,
} from '../core/schemas/orders.schema';

export class OrdersController {
  private getAuthenticatedUserId(req: Request): number {
    if (!req.user?.idUsuario) {
      throw new UnauthorizedError('Usuario no autenticado.');
    }
    return req.user.idUsuario;
  }

  // ==========================================================================
  // 1. CHECKOUT Y PEDIDOS (/api/orders)
  // ==========================================================================

  public createCheckout = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as CheckoutOrderInput;
      const headerKey =
        (req.headers['idempotency-key'] as string | undefined) ??
        (req.headers['x-idempotency-key'] as string | undefined);

      const data = await ordersService.createCheckout(idUsuario, body, headerKey);

      const isIdempotentReplay = Boolean(data.pedido.FueRespuestaIdempotente);

      res.status(isIdempotentReplay ? 200 : 201).json({
        success: true,
        data,
        message: isIdempotentReplay
          ? 'Solicitud idempotente procesada previamente; se devuelve el pedido original.'
          : 'Pedido creado y confirmado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public listOrders = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idUsuarioSolicitante = this.getAuthenticatedUserId(req);
      const query = req.query as unknown as ListOrdersQuery;

      const data = await ordersService.listOrders(idUsuarioSolicitante, query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public getOrderDetail = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuarioSolicitante = this.getAuthenticatedUserId(req);
      const idPedido = Number(req.params.idPedido);

      const data = await ordersService.getOrderDetail(idPedido, idUsuarioSolicitante);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public changeOrderStatus = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idPedido = Number(req.params.idPedido);
      const body = req.body as ChangeOrderStatusInput;

      const data = await ordersService.changeOrderStatus(idPedido, idUsuario, body);

      res.status(200).json({
        success: true,
        data,
        message: `Estado del pedido actualizado a ${body.estadoNuevo} exitosamente.`,
      });
    } catch (error) {
      next(error);
    }
  };

  // ==========================================================================
  // 2. DEVOLUCIONES (/api/returns)
  // ==========================================================================

  public listReturns = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idUsuarioSolicitante = this.getAuthenticatedUserId(req);
      const query = req.query as unknown as ListReturnsQuery;

      const data = await ordersService.listReturns(idUsuarioSolicitante, query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public getReturnDetail = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuarioSolicitante = this.getAuthenticatedUserId(req);
      const idDevolucion = Number(req.params.idDevolucion);

      const data = await ordersService.getReturnDetail(idDevolucion, idUsuarioSolicitante);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public requestReturn = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as RequestReturnInput;

      const data = await ordersService.requestReturn(idUsuario, body);

      res.status(201).json({
        success: true,
        data,
        message: 'Solicitud de devolución registrada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public resolveReturn = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idDevolucion = Number(req.params.idDevolucion);
      const body = req.body as ResolveReturnInput;

      const data = await ordersService.resolveReturn(idDevolucion, idUsuario, body);

      res.status(200).json({
        success: true,
        data,
        message: `Devolución ${body.nuevoEstado.toLowerCase()} exitosamente.`,
      });
    } catch (error) {
      next(error);
    }
  };
}

export const ordersController = new OrdersController();
