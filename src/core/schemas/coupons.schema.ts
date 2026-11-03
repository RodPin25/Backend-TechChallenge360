// src/core/schemas/coupons.schema.ts
import { z } from 'zod';
import { TIPOS_DESCUENTO } from '../constants';

export const createCouponSchema = z.object({
  codigo: z
    .string()
    .trim()
    .min(2, 'El código del cupón debe tener al menos 2 caracteres.')
    .max(30, 'El código del cupón no debe exceder 30 caracteres.')
    .toUpperCase(),
  tipoDescuento: z.enum([TIPOS_DESCUENTO.PORCENTAJE, TIPOS_DESCUENTO.MONTO_FIJO]),
  valorDescuento: z.coerce
    .number()
    .positive('El valor del descuento debe ser mayor a cero.')
    .transform((val) => Number(val.toFixed(2))),
  montoMinimoCompra: z.coerce
    .number()
    .min(0, 'El monto mínimo de compra no puede ser negativo.')
    .default(0)
    .transform((val) => Number(val.toFixed(2))),
  idCategoria: z.coerce.number().int().positive().nullable().optional(),
  fechaInicio: z.coerce.date(),
  fechaFin: z.coerce.date(),
  limiteUsosTotal: z.coerce.number().int().positive('El límite total de usos debe ser mayor a cero.'),
  limiteUsosPorCliente: z.coerce
    .number()
    .int()
    .positive('El límite de usos por cliente debe ser mayor a cero.')
    .default(1),
});

export type CreateCouponInput = z.infer<typeof createCouponSchema>;

export const updateCouponSchema = z.object({
  codigo: z
    .string()
    .trim()
    .min(2, 'El código del cupón debe tener al menos 2 caracteres.')
    .max(30, 'El código del cupón no debe exceder 30 caracteres.')
    .toUpperCase(),
  tipoDescuento: z.enum([TIPOS_DESCUENTO.PORCENTAJE, TIPOS_DESCUENTO.MONTO_FIJO]),
  valorDescuento: z.coerce
    .number()
    .positive('El valor del descuento debe ser mayor a cero.')
    .transform((val) => Number(val.toFixed(2))),
  montoMinimoCompra: z.coerce
    .number()
    .min(0, 'El monto mínimo de compra no puede ser negativo.')
    .default(0)
    .transform((val) => Number(val.toFixed(2))),
  idCategoria: z.coerce.number().int().positive().nullable().optional(),
  fechaInicio: z.coerce.date(),
  fechaFin: z.coerce.date(),
  limiteUsosTotal: z.coerce.number().int().positive('El límite total de usos debe ser mayor a cero.'),
  limiteUsosPorCliente: z.coerce
    .number()
    .int()
    .positive('El límite de usos por cliente debe ser mayor a cero.')
    .default(1),
  activo: z.boolean().default(true),
});

export type UpdateCouponInput = z.infer<typeof updateCouponSchema>;

export const updateCouponStatusSchema = z.object({
  activo: z.boolean(),
});

export type UpdateCouponStatusInput = z.infer<typeof updateCouponStatusSchema>;

export const couponIdParamSchema = z.object({
  idCupon: z.coerce.number().int().positive('El IDCupon debe ser un entero positivo.'),
});

export type CouponIdParam = z.infer<typeof couponIdParamSchema>;

export const listCouponsQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(15),
  activo: z
    .enum(['true', 'false', '1', '0'])
    .transform((val) => val === 'true' || val === '1')
    .optional(),
  soloVigentes: z
    .enum(['true', 'false', '1', '0'])
    .transform((val) => val === 'true' || val === '1')
    .default(false),
  tipoDescuento: z.enum([TIPOS_DESCUENTO.PORCENTAJE, TIPOS_DESCUENTO.MONTO_FIJO]).optional(),
  busqueda: z.string().trim().max(30).optional(),
});

export type ListCouponsQuery = z.infer<typeof listCouponsQuerySchema>;

export const validateCouponInCartSchema = z.object({
  codigo: z
    .string()
    .trim()
    .min(1, 'El código del cupón es obligatorio.')
    .max(30)
    .toUpperCase(),
  tokenInvitado: z.string().trim().max(100).optional(),
});

export type ValidateCouponInCartInput = z.infer<typeof validateCouponInCartSchema>;
