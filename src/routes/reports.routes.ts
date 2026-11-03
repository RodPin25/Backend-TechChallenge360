// src/routes/reports.routes.ts
import { Router } from 'express';
import { reportsController } from '../controllers/reports.controller';
import { authenticateJWT } from '../middlewares/auth.middleware';
import { requireRoles } from '../middlewares/role.middleware';
import { validateRequest } from '../middlewares/validate.middleware';
import { ROLE_NAMES, ROLES } from '../core/constants';
import {
  abandonedCartsQuerySchema,
  consultAuditLogQuerySchema,
  dashboardKpisQuerySchema,
  salesByCategoryQuerySchema,
  salesByPeriodQuerySchema,
  topProductsQuerySchema,
} from '../core/schemas/reports.schema';

// 1. Router de Dashboard y Reportes (/api/reports) - Solo Administrador (RF-01, RF-08)
export const reportsRouter = Router();

reportsRouter.use(authenticateJWT, requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN));

reportsRouter.get(
  '/kpis',
  validateRequest({ query: dashboardKpisQuerySchema }),
  reportsController.getKpis,
);

reportsRouter.get(
  '/sales-by-period',
  validateRequest({ query: salesByPeriodQuerySchema }),
  reportsController.getSalesByPeriod,
);

reportsRouter.get(
  '/sales-by-category',
  validateRequest({ query: salesByCategoryQuerySchema }),
  reportsController.getSalesByCategory,
);

reportsRouter.get(
  '/top-products',
  validateRequest({ query: topProductsQuerySchema }),
  reportsController.getTopProducts,
);

reportsRouter.get(
  '/abandoned-carts',
  validateRequest({ query: abandonedCartsQuerySchema }),
  reportsController.listAbandonedCarts,
);

// 2. Router de Bitácora de Auditoría (/api/audit) - Solo Administrador (RF-01, RF-09)
export const auditRouter = Router();

auditRouter.use(authenticateJWT, requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN));

auditRouter.get(
  '/',
  validateRequest({ query: consultAuditLogQuerySchema }),
  reportsController.consultAuditLog,
);
