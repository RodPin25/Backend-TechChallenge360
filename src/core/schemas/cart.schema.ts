// src/core/schemas/cart.schema.ts
import { z } from 'zod';

export const getCartQuerySchema = z.object({
  tokenInvitado: z.string().trim().max(100).optional(),
  codigoCupon: z.string().trim().max(30).toUpperCase().optional(),
});

export type GetCartQuery = z.infer<typeof getCartQuerySchema>;

export const upsertCartItemSchema = z.object({
  idVariante: z.coerce.number().int().positive('El IDVariante debe ser un entero positivo.'),
  cantidad: z.coerce
    .number()
    .int('La cantidad debe ser un número entero.')
    .positive('La cantidad debe ser mayor a cero.'),
  modoOperacion: z.enum(['SUMAR', 'FIJAR']).default('SUMAR'),
  tokenInvitado: z.string().trim().max(100).optional(),
});

export type UpsertCartItemInput = z.infer<typeof upsertCartItemSchema>;

export const updateCartItemQuantitySchema = z.object({
  cantidad: z.coerce
    .number()
    .int('La cantidad debe ser un número entero.')
    .positive('La cantidad debe ser mayor a cero.'),
  tokenInvitado: z.string().trim().max(100).optional(),
});

export type UpdateCartItemQuantityInput = z.infer<typeof updateCartItemQuantitySchema>;

export const cartVariantParamSchema = z.object({
  idVariante: z.coerce.number().int().positive('El IDVariante debe ser un entero positivo.'),
});

export type CartVariantParam = z.infer<typeof cartVariantParamSchema>;

export const guestTokenOptionalSchema = z.object({
  tokenInvitado: z.string().trim().max(100).optional(),
});

export type GuestTokenOptionalInput = z.infer<typeof guestTokenOptionalSchema>;

export const mergeGuestCartSchema = z.object({
  tokenInvitado: z
    .string()
    .trim()
    .min(1, 'El tokenInvitado es obligatorio para fusionar el carrito.')
    .max(100),
});

export type MergeGuestCartInput = z.infer<typeof mergeGuestCartSchema>;
