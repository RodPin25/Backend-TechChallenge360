// src/config/redis.ts
import { Redis } from 'ioredis';
import { env } from './env';

export const redisClient = new Redis({
  host: env.REDIS_HOST,
  port: env.REDIS_PORT,
  ...(env.REDIS_PASSWORD ? { password: env.REDIS_PASSWORD } : {}),
  lazyConnect: true,
  retryStrategy(times: number): number {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
});


redisClient.on('connect', () => {
  console.log('[REDIS] Conectado al servidor Redis');
});

redisClient.on('error', (err: Error) => {
  console.error('[REDIS] Error de conexión:', err.message);
});
