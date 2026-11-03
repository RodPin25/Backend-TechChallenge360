// src/core/schemas/inventory.schema.ts
import { z } from 'zod';
import { TIPOS_MOVIMIENTO_KARDEX } from '../constants';

export const releaseExpiredReservationsSchema = z.object({
  idVariante: z.coerce.number().int().positive().optional(),
});

export type ReleaseExpiredReservationsInput = z.infer<typeof releaseExpiredReservationsSchema>;

export const reserveStockSchema = z.object({
  idVariante: z.coerce.number().int().positive('El IDVariante debe ser un entero positivo.'),
  cantidad: z.coerce
    .number()
    .int('La cantidad debe ser un número entero.')
    .positive('La cantidad a reservar debe ser mayor a cero.'),
  tokenSesion: z.string().trim().max(100).optional(),
});

export type ReserveStockInput = z.infer<typeof reserveStockSchema>;

export const reserveCartCheckoutSchema = z.object({
  idCarrito: z.coerce.number().int().positive('El IDCarrito debe ser un entero positivo.'),
  tokenSesion: z.string().trim().max(100).optional(),
});

export type ReserveCartCheckoutInput = z.infer<typeof reserveCartCheckoutSchema>;

export const releaseReservationSchema = z.object({
  idReserva: z.coerce.number().int().positive().optional(),
  tokenSesion: z.string().trim().max(100).optional(),
});

export type ReleaseReservationInput = z.infer<typeof releaseReservationSchema>;

export const registerInventoryAdjustmentSchema = z.object({
  idVariante: z.coerce.number().int().positive('El IDVariante debe ser un entero positivo.'),
  tipoMovimiento: z.enum([
    TIPOS_MOVIMIENTO_KARDEX.AJUSTE_ENTRADA,
    TIPOS_MOVIMIENTO_KARDEX.AJUSTE_SALIDA,
  ]),
  cantidad: z.coerce
    .number()
    .int('La cantidad debe ser un número entero.')
    .positive('La cantidad del ajuste debe ser mayor a cero.'),
  motivo: z
    .string()
    .trim()
    .min(3, 'El motivo del ajuste manual es obligatorio (mínimo 3 caracteres).')
    .max(250, 'El motivo no debe exceder 250 caracteres.'),
});

export type RegisterInventoryAdjustmentInput = z.infer<typeof registerInventoryAdjustmentSchema>;

export const consultKardexQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(20),
  idVariante: z.coerce.number().int().positive().optional(),
  idProducto: z.coerce.number().int().positive().optional(),
  tipoMovimiento: z
    .enum([
      TIPOS_MOVIMIENTO_KARDEX.VENTA,
      TIPOS_MOVIMIENTO_KARDEX.AJUSTE_ENTRADA,
      TIPOS_MOVIMIENTO_KARDEX.AJUSTE_SALIDA,
      TIPOS_MOVIMIENTO_KARDEX.DEVOLUCION,
    ])
    .optional(),
  fechaInicio: z.coerce.date().optional(),
  fechaFin: z.coerce.date().optional(),
});

export type ConsultKardexQuery = z.infer<typeof consultKardexQuerySchema>;

export const listStockQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(20),
  idCategoria: z.coerce.number().int().positive().optional(),
  busqueda: z.string().trim().max(150).optional(),
  soloBajoStock: z
    .enum(['true', 'false', '1', '0'])
    .transform((val) => val === 'true' || val === '1')
    .default(false),
  umbralBajoStock: z.coerce.number().int().min(0).default(5),
});

export type ListStockQuery = z.infer<typeof listStockQuerySchema>;
