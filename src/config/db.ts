// src/config/db.ts
import sql, { ConnectionPool, config as SqlConfig } from 'mssql';

const dbConfig: SqlConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  host: process.env.DB_HOST ,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT,
  options: {
    encrypt: true,
    trustServerCertificate: true, 
    enableArithAbort: true,
  },
  pool: {
    max: 10,
    min: 2,
    idleTimeoutMillis: 30000,
  },
};

let pool: ConnectionPool | null = null;

export const connectDatabase = async (): Promise<ConnectionPool> => {
  if (!pool) {
    pool = await new sql.ConnectionPool(dbConfig).connect();
  }
  return pool;
};

export const getPool = (): ConnectionPool => {
  if (!pool) {
    throw new Error('La conexión a la base de datos no ha sido inicializada.');
  }
  return pool;
};

export const closeDatabase = async (): Promise<void> => {
  if (pool) {
    await pool.close();
    pool = null;
  }
};

export { sql };