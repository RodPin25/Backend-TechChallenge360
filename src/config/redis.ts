// src/config/redis.ts
import { Redis } from 'ioredis';
import { env } from './env';

export let isRedisAvailable = false;

export const redisClient = new Redis({
  host: env.REDIS_HOST,
  port: env.REDIS_PORT,
  ...(env.REDIS_PASSWORD ? { password: env.REDIS_PASSWORD } : {}),
  lazyConnect: true,
  enableOfflineQueue: false,
  maxRetriesPerRequest: 1,
  retryStrategy(times: number): number | null {
    // Si falla más de 3 veces al iniciar, dejar de reintentar en bucle para continuar sin Redis
    if (times > 3) {
      isRedisAvailable = false;
      return null;
    }
    return Math.min(times * 200, 1000);
  },
});

redisClient.on('ready', () => {
  isRedisAvailable = true;
  console.log('[REDIS] Conectado al servidor Redis');
});

redisClient.on('end', () => {
  isRedisAvailable = false;
});

redisClient.on('error', (err: Error) => {
  isRedisAvailable = false;
  console.warn(`[REDIS] No disponible (${err.message}). Operando directamente con SQL Server.`);
});

