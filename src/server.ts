// src/server.ts
import app from './app';
import { env } from './config/env';
import { connectDatabase } from './config/db';
import { redisClient } from './config/redis';

async function startServer(): Promise<void> {
  try {
    // Conexión al Pool de SQL Server
    await connectDatabase();
    console.log('[SQL] Conectado a la base de datos SQL Server');

    // Conexión a Redis
    await redisClient.connect();

    // Iniciar el servidor Express
    app.listen(env.API_PORT, () => {
      console.log(`[SERVER] Servidor escuchando en http://localhost:${env.API_PORT} (${env.NODE_ENV})`);
    });
  } catch (error) {
    console.error('[ERROR] Error al iniciar el servidor:', error);
    process.exit(1);
  }
}

void startServer();