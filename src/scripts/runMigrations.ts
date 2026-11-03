import fs from 'fs';
import path from 'path';
import sql, { type config as SqlConfig } from 'mssql';
import { env } from '../config/env';

/**
 * Configuración de conexión para ejecutar migraciones.
 * Permite conectarse a master inicialmente si la BD de destino aún no existe.
 */
const getMasterConfig = (): SqlConfig => ({
  user: env.DB_USER,
  password: env.DB_PASSWORD,
  server: env.DB_HOST,
  database: 'master',
  port: env.DB_PORT,
  options: {
    encrypt: true,
    trustServerCertificate: true,
    enableArithAbort: true,
  },
  requestTimeout: 60000,
});

const getTargetConfig = (): SqlConfig => ({
  user: env.DB_USER,
  password: env.DB_PASSWORD,
  server: env.DB_HOST,
  database: env.DB_NAME,
  port: env.DB_PORT,
  options: {
    encrypt: true,
    trustServerCertificate: true,
    enableArithAbort: true,
  },
  requestTimeout: 60000,
});

/**
 * Asegura la existencia de la base de datos de destino conectándose a 'master'.
 */
const ensureDatabaseExists = async (): Promise<void> => {
  const masterPool = await new sql.ConnectionPool(getMasterConfig()).connect();
  try {
    const dbNameClean = env.DB_NAME.replace(/[^a-zA-Z0-9_]/g, '');
    const checkDbQuery = `
      IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = '${dbNameClean}')
      BEGIN
        CREATE DATABASE [${dbNameClean}];
      END;
    `;
    await masterPool.request().batch(checkDbQuery);
    console.log(`[OK] Base de datos '${env.DB_NAME}' verificada/creada.`);
  } finally {
    await masterPool.close();
  }
};

/**
 * Divide un script SQL por los delimitadores GO de T-SQL.
 */
const splitSqlBatches = (sqlContent: string): string[] => {
  return sqlContent
    .split(/^\s*GO\s*$/gim)
    .map((batch) => batch.trim())
    .filter((batch) => {
      // Ignorar bloques vacíos o con solo comentarios
      const withoutComments = batch
        .replace(/--.*$/gm, '')
        .replace(/\/\*[\s\S]*?\*\//g, '')
        .trim();
      return withoutComments.length > 0;
    });
};

/**
 * Ejecutor principal de migraciones secuenciales.
 */
export const runMigrations = async (): Promise<void> => {
  console.log('=====================================================');
  console.log('       INICIANDO RUNNER DE MIGRACIONES - SHOPCART     ');
  console.log('=====================================================');
  console.log(`Servidor:  ${env.DB_HOST}:${env.DB_PORT}`);
  console.log(`Base datos: ${env.DB_NAME}`);
  console.log(`Usuario:   ${env.DB_USER}`);
  console.log('-----------------------------------------------------');

  await ensureDatabaseExists();

  const migrationsDir = path.resolve(__dirname, '../../migrations');
  if (!fs.existsSync(migrationsDir)) {
    throw new Error(`No se encontró el directorio de migraciones en: ${migrationsDir}`);
  }

  const sqlFiles = fs
    .readdirSync(migrationsDir)
    .filter((file) => file.endsWith('.sql') && !file.startsWith('00_'))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));

  if (sqlFiles.length === 0) {
    console.log('No se encontraron archivos .sql para ejecutar.');
    return;
  }

  console.log(`Se detectaron ${sqlFiles.length} archivos de migración.`);

  const targetPool = await new sql.ConnectionPool(getTargetConfig()).connect();

  try {
    for (const file of sqlFiles) {
      const filePath = path.join(migrationsDir, file);
      const sqlContent = fs.readFileSync(filePath, 'utf-8');
      const batches = splitSqlBatches(sqlContent);

      const startTime = Date.now();
      console.log(`\n⏳ Ejecutando: ${file} (${batches.length} lotes)...`);

      for (const [i, batch] of batches.entries()) {
        if (!batch) continue;
        try {
          await targetPool.request().batch(batch);
        } catch (batchError: any) {
          console.error(`\n❌ Error en archivo '${file}' en el lote ${i + 1}/${batches.length}:`);
          console.error(`Instrucción con fallo:\n${batch.slice(0, 300)}...`);
          console.error(`Mensaje SQL: ${batchError.message}\n`);
          throw batchError;
        }
      }

      const elapsed = Date.now() - startTime;
      console.log(`  ✓ ${file} completado exitosamente en ${elapsed}ms.`);
    }

    console.log('\n=====================================================');
    console.log('   ¡TODAS LAS MIGRACIONES Y SEEDERS FINALIZARON!    ');
    console.log('=====================================================\n');
  } finally {
    await targetPool.close();
  }
};

// Si se ejecuta directamente desde la línea de comandos
if (require.main === module) {
  runMigrations()
    .then(() => {
      process.exit(0);
    })
    .catch((err) => {
      console.error('\n💥 Proceso de migraciones detenido por un error:', err.message);
      process.exit(1);
    });
}
