// src/config/env.ts
import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),

  // Credenciales de SQL Server 2019+
  DB_USER: z.string().min(1, 'DB_USER es requerido'),
  DB_PASSWORD: z.string().min(1, 'DB_PASSWORD es requerido'),
  DB_SERVER: z.string().min(1, 'DB_SERVER es requerido'),
  DB_NAME: z.string().min(1, 'DB_NAME es requerido'),
  DB_PORT: z.coerce.number().default(1433),

  // Seguridad y autenticación
  JWT_SECRET: z.string().min(16, 'JWT_SECRET debe tener al menos 16 caracteres'),
  JWT_EXPIRES_IN: z.string().default('8h'),

  // Constantes de negocio
  IVA_RATE: z.coerce.number().default(0.12),
  RESERVATION_TTL_MINUTES: z.coerce.number().default(15),
});

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  console.error('❌ Error de configuración en las variables de entorno:', parsedEnv.error.format());
  process.exit(1);
}

export const env = parsedEnv.data;