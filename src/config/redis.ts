import Redis from 'ioredis';

export const redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: Number(process.env.REDIS_PORT) || 6379,
    password: process.env.REDIS_PASSWORD || undefined,
    lazyConnect: true, // Para que se conecte solo cuando sea necesario
    retryStrtegy(times) {
        const delay = Math.min(times * 50, 2000);
        return delay;
    },
});

redisClient.on('connect',  () => {
    console.log('[REDIS] Conectado al servidor Redis');
});

redisClient.on('error',(err) =>{
    console.error('[REDIS] Error de conexion:', err);
});
