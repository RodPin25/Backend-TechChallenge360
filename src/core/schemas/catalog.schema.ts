// src/core/schemas/catalog.schema.ts
import { z } from 'zod';

// ============================================================================
// 1. ESQUEMAS DE CATEGORÍAS (/api/catalog/categories)
// ============================================================================

export const createCategorySchema = z.object({
  nombreCategoria: z
    .string()
    .trim()
    .min(2, 'El nombre de la categoría debe tener al menos 2 caracteres.')
    .max(100, 'El nombre de la categoría no debe exceder 100 caracteres.'),
  descripcion: z
    .string()
    .trim()
    .max(250, 'La descripción no debe exceder 250 caracteres.')
    .optional(),
});

export type CreateCategoryInput = z.infer<typeof createCategorySchema>;

export const updateCategorySchema = z.object({
  nombreCategoria: z
    .string()
    .trim()
    .min(2, 'El nombre de la categoría debe tener al menos 2 caracteres.')
    .max(100, 'El nombre de la categoría no debe exceder 100 caracteres.'),
  descripcion: z
    .string()
    .trim()
    .max(250, 'La descripción no debe exceder 250 caracteres.')
    .optional(),
  activo: z.boolean().default(true),
});

export type UpdateCategoryInput = z.infer<typeof updateCategorySchema>;

export const categoryIdParamSchema = z.object({
  idCategoria: z.coerce.number().int().positive('El IDCategoria debe ser un entero positivo.'),
});

export type CategoryIdParam = z.infer<typeof categoryIdParamSchema>;

export const listCategoriesQuerySchema = z.object({
  soloActivas: z
    .enum(['true', 'false', '1', '0'])
    .transform((val) => val === 'true' || val === '1')
    .default(true),
});

export type ListCategoriesQuery = z.infer<typeof listCategoriesQuerySchema>;

// ============================================================================
// 2. ESQUEMAS DE PRODUCTOS (/api/catalog/products)
// ============================================================================

export const createProductSchema = z.object({
  idCategoria: z.coerce.number().int().positive('El IDCategoria debe ser un entero positivo.'),
  nombreProducto: z
    .string()
    .trim()
    .min(2, 'El nombre del producto debe tener al menos 2 caracteres.')
    .max(150, 'El nombre del producto no debe exceder 150 caracteres.'),
  descripcion: z.string().trim().optional(),
});

export type CreateProductInput = z.infer<typeof createProductSchema>;

export const updateProductSchema = z.object({
  idCategoria: z.coerce.number().int().positive('El IDCategoria debe ser un entero positivo.'),
  nombreProducto: z
    .string()
    .trim()
    .min(2, 'El nombre del producto debe tener al menos 2 caracteres.')
    .max(150, 'El nombre del producto no debe exceder 150 caracteres.'),
  descripcion: z.string().trim().optional(),
});

export type UpdateProductInput = z.infer<typeof updateProductSchema>;

export const updateProductStatusSchema = z.object({
  activo: z.boolean(),
});

export type UpdateProductStatusInput = z.infer<typeof updateProductStatusSchema>;

export const productIdParamSchema = z.object({
  idProducto: z.coerce.number().int().positive('El IDProducto debe ser un entero positivo.'),
});

export type ProductIdParam = z.infer<typeof productIdParamSchema>;

export const listProductsQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(12),
  busqueda: z.string().trim().max(150).optional(),
  idCategoria: z.coerce.number().int().positive().optional(),
  precioMinimo: z.coerce
    .number()
    .min(0, 'El precio mínimo no puede ser negativo.')
    .transform((val) => Number(val.toFixed(2)))
    .optional(),
  precioMaximo: z.coerce
    .number()
    .min(0, 'El precio máximo no puede ser negativo.')
    .transform((val) => Number(val.toFixed(2)))
    .optional(),
  soloDisponibles: z
    .enum(['true', 'false', '1', '0'])
    .transform((val) => val === 'true' || val === '1')
    .default(false),
  soloActivos: z
    .enum(['true', 'false', '1', '0'])
    .transform((val) => val === 'true' || val === '1')
    .default(true),
  ordenarPor: z
    .enum(['PRECIO_ASC', 'PRECIO_DESC', 'NOMBRE_ASC', 'NOMBRE_DESC', 'RECIENTES'])
    .default('RECIENTES'),
});

export type ListProductsQuery = z.infer<typeof listProductsQuerySchema>;

export const productDetailQuerySchema = z.object({
  incluirInactivos: z
    .enum(['true', 'false', '1', '0'])
    .transform((val) => val === 'true' || val === '1')
    .default(false),
});

export type ProductDetailQuery = z.infer<typeof productDetailQuerySchema>;

// ============================================================================
// 3. ESQUEMAS DE VARIANTES Y ATRIBUTOS (/api/catalog/variants)
// ============================================================================

export const createVariantSchema = z.object({
  sku: z
    .string()
    .trim()
    .min(2, 'El SKU debe tener al menos 2 caracteres.')
    .max(50, 'El SKU no debe exceder 50 caracteres.')
    .toUpperCase(),
  nombreVariante: z
    .string()
    .trim()
    .min(1, 'El nombre de la variante es obligatorio.')
    .max(100, 'El nombre de la variante no debe exceder 100 caracteres.'),
  precio: z.coerce
    .number()
    .min(0, 'El precio no puede ser negativo.')
    .transform((val) => Number(val.toFixed(2))),
  stockInicial: z.coerce
    .number()
    .int('La existencia inicial debe ser un número entero.')
    .min(0, 'La existencia inicial no puede ser negativa.')
    .default(0),
});

export type CreateVariantInput = z.infer<typeof createVariantSchema>;

export const updateVariantSchema = z.object({
  sku: z
    .string()
    .trim()
    .min(2, 'El SKU debe tener al menos 2 caracteres.')
    .max(50, 'El SKU no debe exceder 50 caracteres.')
    .toUpperCase(),
  nombreVariante: z
    .string()
    .trim()
    .min(1, 'El nombre de la variante es obligatorio.')
    .max(100, 'El nombre de la variante no debe exceder 100 caracteres.'),
  precio: z.coerce
    .number()
    .min(0, 'El precio no puede ser negativo.')
    .transform((val) => Number(val.toFixed(2))),
  activo: z.boolean().default(true),
});

export type UpdateVariantInput = z.infer<typeof updateVariantSchema>;

export const variantIdParamSchema = z.object({
  idVariante: z.coerce.number().int().positive('El IDVariante debe ser un entero positivo.'),
});

export type VariantIdParam = z.infer<typeof variantIdParamSchema>;

export const saveVariantAttributeSchema = z.object({
  clave: z
    .string()
    .trim()
    .min(1, 'La clave del atributo es obligatoria.')
    .max(50, 'La clave no debe exceder 50 caracteres.'),
  valor: z
    .string()
    .trim()
    .min(1, 'El valor del atributo es obligatorio.')
    .max(100, 'El valor no debe exceder 100 caracteres.'),
});

export type SaveVariantAttributeInput = z.infer<typeof saveVariantAttributeSchema>;

export const deleteVariantAttributeParamsSchema = z.object({
  idVariante: z.coerce.number().int().positive('El IDVariante debe ser un entero positivo.'),
  idVarianteAtributo: z.coerce
    .number()
    .int()
    .positive('El IDVarianteAtributo debe ser un entero positivo.'),
});

export type DeleteVariantAttributeParams = z.infer<typeof deleteVariantAttributeParamsSchema>;

export const priceHistoryQuerySchema = z.object({
  idVariante: z.coerce.number().int().positive().optional(),
  idProducto: z.coerce.number().int().positive().optional(),
});

export type PriceHistoryQuery = z.infer<typeof priceHistoryQuerySchema>;

// ============================================================================
// 4. ESQUEMAS DE IMÁGENES DE VARIANTES (/api/catalog/variants/:id/images)
// ============================================================================

export const addVariantImageSchema = z.object({
  urlImagen: z
    .string()
    .trim()
    .min(1, 'La URL de la imagen es obligatoria.')
    .max(500, 'La URL de la imagen no debe exceder 500 caracteres.'),
  esPrincipal: z.boolean().optional().default(false),
  orden: z.coerce.number().int().positive().optional(),
});

export type AddVariantImageInput = z.infer<typeof addVariantImageSchema>;

export const uploadVariantImageBodySchema = z.object({
  esPrincipal: z
    .union([z.boolean(), z.enum(['true', 'false', '1', '0'])])
    .transform((val) => val === true || val === 'true' || val === '1')
    .optional()
    .default(false),
  orden: z.coerce.number().int().positive().optional(),
});

export type UploadVariantImageBody = z.infer<typeof uploadVariantImageBodySchema>;

export const variantImageParamsSchema = z.object({
  idVariante: z.coerce.number().int().positive('El IDVariante debe ser un entero positivo.'),
  idVarianteImagen: z.coerce
    .number()
    .int()
    .positive('El IDVarianteImagen debe ser un entero positivo.'),
});

export type VariantImageParams = z.infer<typeof variantImageParamsSchema>;

