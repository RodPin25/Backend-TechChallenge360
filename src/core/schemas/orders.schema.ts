// src/core/schemas/orders.schema.ts
import { z } from 'zod';
import { ESTADOS_DEVOLUCION, ESTADOS_PEDIDO } from '../constants';

// ============================================================================
// 1. ESQUEMAS DE CHECKOUT Y PEDIDOS (/api/orders)
// ============================================================================

export const checkoutOrderSchema = z.object({
  idDireccion: z.coerce.number().int().positive('El IDDireccion debe ser un entero positivo.'),
  idempotencyKey: z
    .string()
    .trim()
    .min(8, 'La llave de idempotencia debe tener al menos 8 caracteres.')
    .max(64, 'La llave de idempotencia no debe exceder 64 caracteres.')
    .optional(),
  codigoCupon: z.string().trim().max(30).toUpperCase().optional(),
  metodoPago: z.string().trim().min(2).max(30).default('TARJETA'),
  transaccionId: z.string().trim().max(100).optional(),
});

export type CheckoutOrderInput = z.infer<typeof checkoutOrderSchema>;

export const orderIdParamSchema = z.object({
  idPedido: z.coerce.number().int().positive('El IDPedido debe ser un entero positivo.'),
});

export type OrderIdParam = z.infer<typeof orderIdParamSchema>;

export const changeOrderStatusSchema = z.object({
  estadoNuevo: z.enum([
    ESTADOS_PEDIDO.PENDIENTE,
    ESTADOS_PEDIDO.PAGADO,
    ESTADOS_PEDIDO.EN_PREPARACION,
    ESTADOS_PEDIDO.ENVIADO,
    ESTADOS_PEDIDO.ENTREGADO,
    ESTADOS_PEDIDO.CANCELADO,
  ]),
  motivo: z.string().trim().max(250).optional(),
});

export type ChangeOrderStatusInput = z.infer<typeof changeOrderStatusSchema>;

export const listOrdersQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(15),
  estadoPedido: z
    .enum([
      ESTADOS_PEDIDO.PENDIENTE,
      ESTADOS_PEDIDO.PAGADO,
      ESTADOS_PEDIDO.EN_PREPARACION,
      ESTADOS_PEDIDO.ENVIADO,
      ESTADOS_PEDIDO.ENTREGADO,
      ESTADOS_PEDIDO.CANCELADO,
    ])
    .optional(),
  idCliente: z.coerce.number().int().positive().optional(),
  fechaInicio: z.coerce.date().optional(),
  fechaFin: z.coerce.date().optional(),
});

export type ListOrdersQuery = z.infer<typeof listOrdersQuerySchema>;

// ============================================================================
// 2. ESQUEMAS DE DEVOLUCIONES (/api/returns)
// ============================================================================

export const returnItemSchema = z.object({
  idVariante: z.coerce.number().int().positive('El IDVariante debe ser un entero positivo.'),
  cantidad: z.coerce
    .number()
    .int('La cantidad debe ser un número entero.')
    .positive('La cantidad a devolver debe ser mayor a cero.'),
});

export const requestReturnSchema = z.object({
  idPedido: z.coerce.number().int().positive('El IDPedido debe ser un entero positivo.'),
  motivo: z
    .string()
    .trim()
    .min(5, 'El motivo de la devolución debe tener al menos 5 caracteres.')
    .max(250, 'El motivo no debe exceder 250 caracteres.'),
  items: z
    .array(returnItemSchema)
    .min(1, 'Debe incluir al menos una línea de producto para devolver.'),
});

export type RequestReturnInput = z.infer<typeof requestReturnSchema>;

export const returnIdParamSchema = z.object({
  idDevolucion: z.coerce.number().int().positive('El IDDevolucion debe ser un entero positivo.'),
});

export type ReturnIdParam = z.infer<typeof returnIdParamSchema>;

export const resolveReturnSchema = z.object({
  nuevoEstado: z.enum([ESTADOS_DEVOLUCION.APROBADA, ESTADOS_DEVOLUCION.RECHAZADA]),
  observacion: z.string().trim().max(250).optional(),
});

export type ResolveReturnInput = z.infer<typeof resolveReturnSchema>;

export const listReturnsQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(15),
  estado: z
    .enum([
      ESTADOS_DEVOLUCION.SOLICITADA,
      ESTADOS_DEVOLUCION.APROBADA,
      ESTADOS_DEVOLUCION.RECHAZADA,
    ])
    .optional(),
  idPedido: z.coerce.number().int().positive().optional(),
  idCliente: z.coerce.number().int().positive().optional(),
  fechaInicio: z.coerce.date().optional(),
  fechaFin: z.coerce.date().optional(),
});

export type ListReturnsQuery = z.infer<typeof listReturnsQuerySchema>;
