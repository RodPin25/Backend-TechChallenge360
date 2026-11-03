// src/routes/inventory.routes.ts
import { Router } from 'express';
import { inventoryController } from '../controllers/inventory.controller';
import { authenticateJWT, optionalAuthenticateJWT } from '../middlewares/auth.middleware';
import { requireRoles } from '../middlewares/role.middleware';
import { validateRequest } from '../middlewares/validate.middleware';
import { ROLE_NAMES, ROLES } from '../core/constants';
import {
  consultKardexQuerySchema,
  listStockQuerySchema,
  registerInventoryAdjustmentSchema,
  releaseExpiredReservationsSchema,
  releaseReservationSchema,
  reserveCartCheckoutSchema,
  reserveStockSchema,
} from '../core/schemas/inventory.schema';

export const inventoryRouter = Router();

// Operaciones exclusivas de Operador y Administrador (RF-01, RF-03)
inventoryRouter.get(
  '/stock',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  validateRequest({ query: listStockQuerySchema }),
  inventoryController.listStock,
);

inventoryRouter.get(
  '/kardex',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  validateRequest({ query: consultKardexQuerySchema }),
  inventoryController.consultKardex,
);

inventoryRouter.post(
  '/adjustments',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  validateRequest({ body: registerInventoryAdjustmentSchema }),
  inventoryController.registerAdjustment,
);

inventoryRouter.post(
  '/reservations/release-expired',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  validateRequest({ body: releaseExpiredReservationsSchema }),
  inventoryController.releaseExpiredReservations,
);

// Reservas temporales en proceso de compra / checkout (RF-06)
inventoryRouter.post(
  '/reservations',
  optionalAuthenticateJWT,
  validateRequest({ body: reserveStockSchema }),
  inventoryController.reserveStock,
);

inventoryRouter.post(
  '/reservations/cart',
  optionalAuthenticateJWT,
  validateRequest({ body: reserveCartCheckoutSchema }),
  inventoryController.reserveCartCheckout,
);

inventoryRouter.post(
  '/reservations/release',
  optionalAuthenticateJWT,
  validateRequest({ body: releaseReservationSchema }),
  inventoryController.releaseReservation,
);
