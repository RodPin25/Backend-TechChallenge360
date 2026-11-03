// src/server.ts
import app from './app';
import { env } from './config/env';
import { connectDatabase } from './config/db';
import { redisClient } from './config/redis';

async function startServer(): Promise<void> {
  try {
    // 1. Conexión obligatoria al Pool de SQL Server
    await connectDatabase();
    console.log('[SQL] Conectado a la base de datos SQL Server');

    // 2. Conexión opcional a Redis (si falla, el servidor continúa sin caché)
    try {
      await redisClient.connect();
    } catch {
      console.warn(
        '[REDIS] No se pudo establecer conexión inicial con Redis. El servidor continuará funcionando sin caché en memoria.',
      );
    }

    // 3. Iniciar el servidor Express
    app.listen(env.API_PORT, () => {
      console.log(
        `[SERVER] Servidor escuchando en http://localhost:${env.API_PORT} (${env.NODE_ENV})`,
      );
    });
  } catch (error) {
    console.error('[ERROR] Error crítico al iniciar el servidor:', error);
    process.exit(1);
  }
}

void startServer();