// src/routes/auth.routes.ts
import { Router } from 'express';
import { authController } from '../controllers/auth.controller';
import { authenticateJWT } from '../middlewares/auth.middleware';
import { requireRoles } from '../middlewares/role.middleware';
import { validateRequest } from '../middlewares/validate.middleware';
import { ROLE_NAMES, ROLES } from '../core/constants';
import {
  addressIdParamSchema,
  createAddressSchema,
  createUserByAdminSchema,
  listUsersQuerySchema,
  loginSchema,
  refreshTokenSchema,
  registerClientSchema,
  updateAddressSchema,
  updateProfileSchema,
  updateUserStatusSchema,
  userIdParamSchema,
} from '../core/schemas/auth.schema';

// 1. Router de Autenticación (/api/auth)
export const authRouter = Router();

authRouter.post(
  '/register',
  validateRequest({ body: registerClientSchema }),
  authController.register,
);

authRouter.post(
  '/login',
  validateRequest({ body: loginSchema }),
  authController.login,
);

authRouter.post(
  '/refresh',
  validateRequest({ body: refreshTokenSchema }),
  authController.refresh,
);

authRouter.post('/logout', authController.logout);

authRouter.get('/me', authenticateJWT, authController.getMe);

authRouter.put(
  '/me',
  authenticateJWT,
  validateRequest({ body: updateProfileSchema }),
  authController.updateMe,
);

// 2. Router de Administración de Usuarios (/api/users)
export const usersRouter = Router();

usersRouter.use(authenticateJWT, requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN));

usersRouter.get(
  '/roles',
  authController.listRoles,
);

usersRouter.get(
  '/',
  validateRequest({ query: listUsersQuerySchema }),
  authController.listUsers,
);

usersRouter.post(
  '/',
  validateRequest({ body: createUserByAdminSchema }),
  authController.createUserByAdmin,
);

usersRouter.patch(
  '/:idUsuario/status',
  validateRequest({ params: userIdParamSchema, body: updateUserStatusSchema }),
  authController.updateUserStatus,
);

// 3. Router de Direcciones de Entrega (/api/addresses)
export const addressesRouter = Router();

addressesRouter.use(authenticateJWT);

addressesRouter.get('/', authController.listAddresses);

addressesRouter.post(
  '/',
  validateRequest({ body: createAddressSchema }),
  authController.createAddress,
);

addressesRouter.put(
  '/:idDireccion',
  validateRequest({ params: addressIdParamSchema, body: updateAddressSchema }),
  authController.updateAddress,
);

addressesRouter.patch(
  '/:idDireccion/principal',
  validateRequest({ params: addressIdParamSchema }),
  authController.setPrimaryAddress,
);

addressesRouter.delete(
  '/:idDireccion',
  validateRequest({ params: addressIdParamSchema }),
  authController.deactivateAddress,
);
