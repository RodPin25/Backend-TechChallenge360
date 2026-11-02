// src/app.ts
import express, { type Application, type Request, type Response } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { authRouter, usersRouter, addressesRouter } from './routes/auth.routes';
import { notFoundHandler, errorHandler } from './middlewares/errorHandler';

const app: Application = express();

// Configuraciones de seguridad y middlewares globales
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Endpoint de verificación de salud
app.get('/api/health', (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    message: 'ShopCart API funcionando correctamente.',
  });
});

// Rutas del Módulo 1 (RF-01: Autenticación, Usuarios y Direcciones)
app.use('/api/auth', authRouter);
app.use('/api/users', usersRouter);
app.use('/api/addresses', addressesRouter);

// Manejo de rutas inexistentes (404) y middleware global de errores
app.use(notFoundHandler);
app.use(errorHandler);

export default app;