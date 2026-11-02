// src/core/schemas/auth.schema.ts
import { z } from 'zod';

// ============================================================================
// 1. ESQUEMAS DE AUTENTICACIÓN Y PERFIL (/api/auth)
// ============================================================================

export const registerClientSchema = z.object({
  correo: z
    .email('Formato de correo electrónico inválido.')
    .max(120, 'El correo no debe exceder 120 caracteres.')
    .trim()
    .toLowerCase(),
  password: z
    .string()
    .min(8, 'La contraseña debe tener al menos 8 caracteres.')
    .max(72, 'La contraseña no debe exceder 72 caracteres.'),
  nombreCompleto: z
    .string()
    .trim()
    .min(2, 'El nombre completo debe tener al menos 2 caracteres.')
    .max(120, 'El nombre completo no debe exceder 120 caracteres.'),
  telefono: z
    .string()
    .trim()
    .max(20, 'El teléfono no debe exceder 20 caracteres.')
    .optional(),
});

export type RegisterClientInput = z.infer<typeof registerClientSchema>;

export const loginSchema = z.object({
  correo: z
    .email('Formato de correo electrónico inválido.')
    .max(120)
    .trim()
    .toLowerCase(),
  password: z.string().min(1, 'La contraseña es requerida.'),
});

export type LoginInput = z.infer<typeof loginSchema>;

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'El refresh token es requerido.'),
});

export type RefreshTokenInput = z.infer<typeof refreshTokenSchema>;

export const updateProfileSchema = z.object({
  nombreCompleto: z
    .string()
    .trim()
    .min(2, 'El nombre completo debe tener al menos 2 caracteres.')
    .max(120, 'El nombre completo no debe exceder 120 caracteres.'),
  telefono: z
    .string()
    .trim()
    .max(20, 'El teléfono no debe exceder 20 caracteres.')
    .optional(),
  password: z
    .string()
    .min(8, 'La nueva contraseña debe tener al menos 8 caracteres.')
    .max(72, 'La nueva contraseña no debe exceder 72 caracteres.')
    .optional(),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;

// ============================================================================
// 2. ESQUEMAS DE ADMINISTRACIÓN DE USUARIOS (/api/users)
// ============================================================================

export const createUserByAdminSchema = z.object({
  idRol: z.coerce.number().int().positive('El IDRol debe ser un entero positivo.'),
  correo: z
    .email('Formato de correo electrónico inválido.')
    .max(120, 'El correo no debe exceder 120 caracteres.')
    .trim()
    .toLowerCase(),
  password: z
    .string()
    .min(8, 'La contraseña debe tener al menos 8 caracteres.')
    .max(72, 'La contraseña no debe exceder 72 caracteres.'),
  nombreCompleto: z
    .string()
    .trim()
    .min(2, 'El nombre completo debe tener al menos 2 caracteres.')
    .max(120, 'El nombre completo no debe exceder 120 caracteres.'),
  telefono: z
    .string()
    .trim()
    .max(20, 'El teléfono no debe exceder 20 caracteres.')
    .optional(),
});

export type CreateUserByAdminInput = z.infer<typeof createUserByAdminSchema>;

export const updateUserStatusSchema = z.object({
  activo: z.boolean(),
  idRol: z.coerce.number().int().positive().optional(),
});

export type UpdateUserStatusInput = z.infer<typeof updateUserStatusSchema>;

export const userIdParamSchema = z.object({
  idUsuario: z.coerce.number().int().positive('El IDUsuario debe ser un entero positivo.'),
});

export type UserIdParam = z.infer<typeof userIdParamSchema>;

export const listUsersQuerySchema = z.object({
  numeroPagina: z.coerce.number().int().min(1).default(1),
  tamanoPagina: z.coerce.number().int().min(1).max(100).default(10),
  idRol: z.coerce.number().int().positive().optional(),
  activo: z
    .enum(['true', 'false', '1', '0'])
    .transform((val) => val === 'true' || val === '1')
    .optional(),
  busqueda: z.string().trim().max(120).optional(),
});

export type ListUsersQuery = z.infer<typeof listUsersQuerySchema>;

// ============================================================================
// 3. ESQUEMAS DE DIRECCIONES DE ENTREGA (/api/addresses)
// ============================================================================

export const createAddressSchema = z.object({
  direccionLinea: z
    .string()
    .trim()
    .min(5, 'La dirección debe tener al menos 5 caracteres.')
    .max(200, 'La dirección no debe exceder 200 caracteres.'),
  municipio: z
    .string()
    .trim()
    .min(2, 'El municipio es obligatorio.')
    .max(100, 'El municipio no debe exceder 100 caracteres.'),
  departamento: z
    .string()
    .trim()
    .min(2, 'El departamento es obligatorio.')
    .max(100, 'El departamento no debe exceder 100 caracteres.'),
  codigoPostal: z
    .string()
    .trim()
    .max(10, 'El código postal no debe exceder 10 caracteres.')
    .optional(),
  referencia: z
    .string()
    .trim()
    .max(200, 'La referencia no debe exceder 200 caracteres.')
    .optional(),
  esPrincipal: z.boolean().default(false),
});

export type CreateAddressInput = z.infer<typeof createAddressSchema>;

export const updateAddressSchema = z.object({
  direccionLinea: z
    .string()
    .trim()
    .min(5, 'La dirección debe tener al menos 5 caracteres.')
    .max(200, 'La dirección no debe exceder 200 caracteres.'),
  municipio: z
    .string()
    .trim()
    .min(2, 'El municipio es obligatorio.')
    .max(100, 'El municipio no debe exceder 100 caracteres.'),
  departamento: z
    .string()
    .trim()
    .min(2, 'El departamento es obligatorio.')
    .max(100, 'El departamento no debe exceder 100 caracteres.'),
  codigoPostal: z
    .string()
    .trim()
    .max(10, 'El código postal no debe exceder 10 caracteres.')
    .optional(),
  referencia: z
    .string()
    .trim()
    .max(200, 'La referencia no debe exceder 200 caracteres.')
    .optional(),
  esPrincipal: z.boolean().optional(),
});

export type UpdateAddressInput = z.infer<typeof updateAddressSchema>;

export const addressIdParamSchema = z.object({
  idDireccion: z.coerce.number().int().positive('El IDDireccion debe ser un entero positivo.'),
});

export type AddressIdParam = z.infer<typeof addressIdParamSchema>;
