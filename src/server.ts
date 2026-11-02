import app from './app';
import {sql} from './config/db';
import {redisClient} from './config/redis';

const PORT = process.env.API_PORT || 3000;

async function startServer() {
    try{
        // Conexion a la base de datos SQL Server
        await sql.connect();
        console.log('[SQL] Conectado a la base de datos SQL Server');

        // Conexion a Redis
        await redisClient.connect();
        console.log('[REDIS] Conectado al servidor Redis');

        // Iniciar el servidor Express
        app.listen(PORT, () => {
            console.log(`Servidor escuchando en http://localhost:${PORT}`);
        });
    } catch(error){
        console.error('[ERROR] Error al iniciar el servidor:', error);
    }
}