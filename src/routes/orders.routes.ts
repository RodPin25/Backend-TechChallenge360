// src/routes/orders.routes.ts
import { Router } from 'express';
import { ordersController } from '../controllers/orders.controller';
import { authenticateJWT } from '../middlewares/auth.middleware';
import { requireRoles } from '../middlewares/role.middleware';
import { validateRequest } from '../middlewares/validate.middleware';
import { ROLE_NAMES, ROLES } from '../core/constants';
import {
  changeOrderStatusSchema,
  checkoutOrderSchema,
  listOrdersQuerySchema,
  listReturnsQuerySchema,
  orderIdParamSchema,
  requestReturnSchema,
  resolveReturnSchema,
  returnIdParamSchema,
} from '../core/schemas/orders.schema';

// 1. Router de Pedidos y Checkout (/api/orders)
export const ordersRouter = Router();

ordersRouter.use(authenticateJWT);

ordersRouter.post(
  '/checkout',
  validateRequest({ body: checkoutOrderSchema }),
  ordersController.createCheckout,
);

ordersRouter.get(
  '/',
  validateRequest({ query: listOrdersQuerySchema }),
  ordersController.listOrders,
);

ordersRouter.get(
  '/:idPedido',
  validateRequest({ params: orderIdParamSchema }),
  ordersController.getOrderDetail,
);

ordersRouter.patch(
  '/:idPedido/status',
  validateRequest({ params: orderIdParamSchema, body: changeOrderStatusSchema }),
  ordersController.changeOrderStatus,
);

// 2. Router de Devoluciones (/api/returns)
export const returnsRouter = Router();

returnsRouter.use(authenticateJWT);

returnsRouter.get(
  '/',
  validateRequest({ query: listReturnsQuerySchema }),
  ordersController.listReturns,
);

returnsRouter.get(
  '/:idDevolucion',
  validateRequest({ params: returnIdParamSchema }),
  ordersController.getReturnDetail,
);

returnsRouter.post(
  '/',
  validateRequest({ body: requestReturnSchema }),
  ordersController.requestReturn,
);

returnsRouter.patch(
  '/:idDevolucion/resolve',
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  validateRequest({ params: returnIdParamSchema, body: resolveReturnSchema }),
  ordersController.resolveReturn,
);
