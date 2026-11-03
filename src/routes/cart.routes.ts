// src/routes/cart.routes.ts
import { Router } from 'express';
import { cartController } from '../controllers/cart.controller';
import { authenticateJWT, optionalAuthenticateJWT } from '../middlewares/auth.middleware';
import { validateRequest } from '../middlewares/validate.middleware';
import {
  cartVariantParamSchema,
  getCartQuerySchema,
  mergeGuestCartSchema,
  updateCartItemQuantitySchema,
  upsertCartItemSchema,
} from '../core/schemas/cart.schema';

export const cartRouter = Router();

cartRouter.get(
  '/',
  optionalAuthenticateJWT,
  validateRequest({ query: getCartQuerySchema }),
  cartController.getCart,
);

cartRouter.post(
  '/items',
  optionalAuthenticateJWT,
  validateRequest({ body: upsertCartItemSchema }),
  cartController.addOrUpdateItem,
);

cartRouter.put(
  '/items/:idVariante',
  optionalAuthenticateJWT,
  validateRequest({ params: cartVariantParamSchema, body: updateCartItemQuantitySchema }),
  cartController.setItemQuantity,
);

cartRouter.delete(
  '/items/:idVariante',
  optionalAuthenticateJWT,
  validateRequest({ params: cartVariantParamSchema }),
  cartController.removeItem,
);

cartRouter.delete(
  '/',
  optionalAuthenticateJWT,
  cartController.clearCart,
);

cartRouter.post(
  '/merge',
  authenticateJWT,
  validateRequest({ body: mergeGuestCartSchema }),
  cartController.mergeGuestCart,
);
