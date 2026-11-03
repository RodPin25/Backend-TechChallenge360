// src/core/schemas/reports.schema.ts
import { z } from 'zod';
import { ACCIONES_BITACORA } from '../constants';

export const dashboardKpisQuerySchema = z.object({
  fechaInicio: z.coerce.date().optional(),
  fechaFin: z.coerce.date().optional(),
  minutosAbandono: z.coerce.number().int().min(1).default(60),
});

export type DashboardKpisQuery = z.infer<typeof dashboardKpisQuerySchema>;

export const salesByPeriodQuerySchema = z.object({
  agrupacion: z.enum(['DIA', 'SEMANA', 'MES']).default('DIA'),
  fechaInicio: z.coerce.date().optional(),
  fechaFin: z.coerce.date().optional(),
});

export type SalesByPeriodQuery = z.infer<typeof salesByPeriodQuerySchema>;

export const salesByCategoryQuerySchema = z.object({
  fechaInicio: z.coerce.date().optional(),
  fechaFin: z.coerce.date().optional(),
});

export type SalesByCategoryQuery = z.infer<typeof salesByCategoryQuerySchema>;

export const topProductsQuerySchema = z.object({
  fechaInicio: z.coerce.date().optional(),
  fechaFin: z.coerce.date().optional(),
  topN: z.coerce.number().int().min(1).max(50).default(10),
});

export type TopProductsQuery = z.infer<typeof topProductsQuerySchema>;

export const abandonedCartsQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(15),
  minutosInactividad: z.coerce.number().int().min(0).default(60),
});

export type AbandonedCartsQuery = z.infer<typeof abandonedCartsQuerySchema>;

export const consultAuditLogQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(25),
  modulo: z.string().trim().max(50).toUpperCase().optional(),
  accion: z
    .enum([
      ACCIONES_BITACORA.CREAR,
      ACCIONES_BITACORA.MODIFICAR,
      ACCIONES_BITACORA.DESACTIVAR,
    ])
    .optional(),
  idUsuario: z.coerce.number().int().positive().optional(),
  fechaInicio: z.coerce.date().optional(),
  fechaFin: z.coerce.date().optional(),
});

export type ConsultAuditLogQuery = z.infer<typeof consultAuditLogQuerySchema>;
