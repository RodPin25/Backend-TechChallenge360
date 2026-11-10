// src/app.ts
import express, { type Application, type Request, type Response } from 'express';
import path from 'path';
import helmet from 'helmet';
import cors from 'cors';
import { swaggerRouter } from './config/swagger';
import { authRouter, usersRouter, addressesRouter } from './routes/auth.routes';
import { catalogRouter } from './routes/catalog.routes';
import { inventoryRouter } from './routes/inventory.routes';
import { cartRouter } from './routes/cart.routes';
import { couponsRouter } from './routes/coupons.routes';
import { ordersRouter, returnsRouter } from './routes/orders.routes';
import { reportsRouter, auditRouter } from './routes/reports.routes';
import { notFoundHandler, errorHandler } from './middlewares/errorHandler';

const app: Application = express();

// Configuraciones de seguridad y middlewares globales
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  }),
);
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servidor de archivos estáticos para imágenes de productos/variantes
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

// Documentación interactiva OpenAPI / Swagger UI (/api/docs y /api/docs.json)
app.use('/api', swaggerRouter);

// Endpoint de verificación de salud
app.get('/api/health', (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    message: 'ShopCart API funcionando correctamente.',
  });
});


// Módulo 1 (RF-01: Autenticación, Usuarios y Direcciones)
app.use('/api/auth', authRouter);
app.use('/api/users', usersRouter);
app.use('/api/addresses', addressesRouter);

// Módulo 2 (RF-02: Catálogo de Productos, Categorías y Variantes)
app.use('/api/catalog', catalogRouter);

// Módulo 3 (RF-03, RF-06: Inventario, Kardex y Reservas Temporales)
app.use('/api/inventory', inventoryRouter);

// Módulo 4 (RF-04: Carrito de Compras)
app.use('/api/cart', cartRouter);

// Módulo 5 (RF-05: Cupones y Promociones)
app.use('/api/coupons', couponsRouter);

// Módulos 6 y 7 (RF-06, RF-07: Checkout, Pedidos y Devoluciones)
app.use('/api/orders', ordersRouter);
app.use('/api/returns', returnsRouter);

// Módulos 8 y 9 (RF-08, RF-09: Dashboard, Reportes y Bitácora Inmutable)
app.use('/api/reports', reportsRouter);
app.use('/api/audit', auditRouter);

// Manejo de rutas inexistentes (404) y middleware global de errores
app.use(notFoundHandler);
app.use(errorHandler);

export default app;