// src/routes/coupons.routes.ts
import { Router } from 'express';
import { couponsController } from '../controllers/coupons.controller';
import { authenticateJWT, optionalAuthenticateJWT } from '../middlewares/auth.middleware';
import { requireRoles } from '../middlewares/role.middleware';
import { validateRequest } from '../middlewares/validate.middleware';
import { ROLE_NAMES, ROLES } from '../core/constants';
import {
  couponIdParamSchema,
  createCouponSchema,
  listCouponsQuerySchema,
  updateCouponSchema,
  updateCouponStatusSchema,
  validateCouponInCartSchema,
} from '../core/schemas/coupons.schema';

export const couponsRouter = Router();

// Validación pública/cliente de cupón sobre carrito activo (RF-05)
couponsRouter.post(
  '/validate',
  optionalAuthenticateJWT,
  validateRequest({ body: validateCouponInCartSchema }),
  couponsController.validateInCart,
);

// CRUD administrativo de cupones (Solo Administrador - RF-01, RF-05)
couponsRouter.get(
  '/',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ query: listCouponsQuerySchema }),
  couponsController.listCoupons,
);

couponsRouter.get(
  '/:idCupon',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: couponIdParamSchema }),
  couponsController.getCouponById,
);

couponsRouter.post(
  '/',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ body: createCouponSchema }),
  couponsController.createCoupon,
);

couponsRouter.put(
  '/:idCupon',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: couponIdParamSchema, body: updateCouponSchema }),
  couponsController.updateCoupon,
);

couponsRouter.patch(
  '/:idCupon/status',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: couponIdParamSchema, body: updateCouponStatusSchema }),
  couponsController.updateCouponStatus,
);
