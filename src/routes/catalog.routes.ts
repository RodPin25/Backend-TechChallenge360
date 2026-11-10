// src/routes/catalog.routes.ts
import { Router } from 'express';
import { catalogController } from '../controllers/catalog.controller';
import { authenticateJWT, optionalAuthenticateJWT } from '../middlewares/auth.middleware';
import { requireRoles } from '../middlewares/role.middleware';
import { validateRequest } from '../middlewares/validate.middleware';
import { uploadVariantImage } from '../middlewares/upload.middleware';
import { ROLE_NAMES, ROLES } from '../core/constants';
import {
  addVariantImageSchema,
  categoryIdParamSchema,
  createCategorySchema,
  createProductSchema,
  createVariantSchema,
  deleteVariantAttributeParamsSchema,
  listCategoriesQuerySchema,
  listProductsQuerySchema,
  priceHistoryQuerySchema,
  productDetailQuerySchema,
  productIdParamSchema,
  saveVariantAttributeSchema,
  updateCategorySchema,
  updateProductSchema,
  updateProductStatusSchema,
  updateVariantSchema,
  uploadVariantImageBodySchema,
  variantIdParamSchema,
  variantImageParamsSchema,
} from '../core/schemas/catalog.schema';

export const catalogRouter = Router();

// ============================================================================
// 1. CATEGORÍAS (/api/catalog/categories)
// ============================================================================

catalogRouter.get(
  '/categories',
  optionalAuthenticateJWT,
  validateRequest({ query: listCategoriesQuerySchema }),
  catalogController.listCategories,
);

catalogRouter.post(
  '/categories',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ body: createCategorySchema }),
  catalogController.createCategory,
);

catalogRouter.put(
  '/categories/:idCategoria',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: categoryIdParamSchema, body: updateCategorySchema }),
  catalogController.updateCategory,
);

// ============================================================================
// 2. PRODUCTOS (/api/catalog/products)
// ============================================================================

catalogRouter.get(
  '/products',
  optionalAuthenticateJWT,
  validateRequest({ query: listProductsQuerySchema }),
  catalogController.listProducts,
);

catalogRouter.get(
  '/products/:idProducto',
  optionalAuthenticateJWT,
  validateRequest({ params: productIdParamSchema, query: productDetailQuerySchema }),
  catalogController.getProductDetail,
);

catalogRouter.post(
  '/products',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ body: createProductSchema }),
  catalogController.createProduct,
);

catalogRouter.put(
  '/products/:idProducto',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: productIdParamSchema, body: updateProductSchema }),
  catalogController.updateProduct,
);

catalogRouter.patch(
  '/products/:idProducto/status',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: productIdParamSchema, body: updateProductStatusSchema }),
  catalogController.updateProductStatus,
);

// ============================================================================
// 3. VARIANTES, ATRIBUTOS E HISTORIAL DE PRECIOS (/api/catalog/...)
// ============================================================================

catalogRouter.post(
  '/products/:idProducto/variants',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: productIdParamSchema, body: createVariantSchema }),
  catalogController.createVariant,
);

catalogRouter.put(
  '/variants/:idVariante',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: variantIdParamSchema, body: updateVariantSchema }),
  catalogController.updateVariant,
);

catalogRouter.post(
  '/variants/:idVariante/attributes',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: variantIdParamSchema, body: saveVariantAttributeSchema }),
  catalogController.saveVariantAttribute,
);

catalogRouter.delete(
  '/variants/:idVariante/attributes/:idVarianteAtributo',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ params: deleteVariantAttributeParamsSchema }),
  catalogController.deleteVariantAttribute,
);

catalogRouter.get(
  '/price-history',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLE_NAMES.ADMIN),
  validateRequest({ query: priceHistoryQuerySchema }),
  catalogController.getPriceHistory,
);

// ============================================================================
// 4. IMÁGENES DE VARIANTES (/api/catalog/variants/:idVariante/images)
// ============================================================================

// Subida física de archivo multimedia (multipart/form-data)
catalogRouter.post(
  '/variants/:idVariante/images/upload',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  uploadVariantImage.single('file'),
  validateRequest({
    params: variantIdParamSchema,
    body: uploadVariantImageBodySchema,
  }),
  catalogController.uploadVariantImage,
);

// Asociación mediante URL directa (application/json)
catalogRouter.post(
  '/variants/:idVariante/images',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  validateRequest({
    params: variantIdParamSchema,
    body: addVariantImageSchema,
  }),
  catalogController.addVariantImage,
);

// Establecer imagen como principal de la variante
catalogRouter.patch(
  '/variants/:idVariante/images/:idVarianteImagen/primary',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  validateRequest({ params: variantImageParamsSchema }),
  catalogController.setPrimaryVariantImage,
);

// Desactivación lógica de imagen de la variante
catalogRouter.delete(
  '/variants/:idVariante/images/:idVarianteImagen',
  authenticateJWT,
  requireRoles(ROLES.ADMIN, ROLES.OPERADOR, ROLE_NAMES.ADMIN, ROLE_NAMES.OPERADOR),
  validateRequest({ params: variantImageParamsSchema }),
  catalogController.deleteVariantImage,
);

