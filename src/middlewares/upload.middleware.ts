// src/middlewares/upload.middleware.ts
import fs from 'fs';
import path from 'path';
import { AppError, BadRequestError } from '../core/errors';
import type { Request, Response, NextFunction } from 'express';

export interface UploadedFile {
  fieldname: string;
  originalname: string;
  encoding: string;
  mimetype: string;
  size: number;
  destination: string;
  filename: string;
  path: string;
  buffer?: Buffer;
}

declare global {
  namespace Express {
    namespace Multer {
      type File = UploadedFile;
    }
    interface Request {
      file?: UploadedFile;
      files?: UploadedFile[] | { [fieldname: string]: UploadedFile[] };
    }
  }
}

const UPLOAD_DIR = path.join(process.cwd(), 'uploads/variantes');

// Asegurar existencia preventiva del directorio de almacenamiento local
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/jpg']);

// Carga resiliente de Multer: evita que el servidor crashee si no se ha ejecutado npm install
let multerInstance: any = null;

try {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const multer = require('multer');

  const storage = multer.diskStorage({
    destination: (
      _req: Request,
      _file: Express.Multer.File,
      cb: (error: Error | null, destination: string) => void,
    ) => {
      if (!fs.existsSync(UPLOAD_DIR)) {
        fs.mkdirSync(UPLOAD_DIR, { recursive: true });
      }
      cb(null, UPLOAD_DIR);
    },
    filename: (
      req: Request,
      file: Express.Multer.File,
      cb: (error: Error | null, filename: string) => void,
    ) => {
      const idVariante = req.params.idVariante ?? 'v';
      const timestamp = Date.now();
      const random = Math.round(Math.random() * 1e9);
      const ext = path.extname(file.originalname).toLowerCase() || '.webp';
      cb(null, `var-${idVariante}-${timestamp}-${random}${ext}`);
    },
  });

  multerInstance = multer({
    storage,
    limits: {
      fileSize: 5 * 1024 * 1024, // 5 MB
      files: 1,
    },
    fileFilter: (
      _req: Request,
      file: Express.Multer.File,
      cb: (error: Error | null, accept?: boolean) => void,
    ) => {
      if (!ALLOWED_MIME_TYPES.has(file.mimetype.toLowerCase())) {
        return cb(
          new BadRequestError(
            'Formato de archivo no permitido. Solo se aceptan imágenes JPEG, PNG o WebP.',
          ),
        );
      }
      cb(null, true);
    },
  });
} catch {
  // Multer aún no ha sido descargado en node_modules
  multerInstance = null;
}

export const uploadVariantImage = {
  single: (fieldName: string) => {
    return (req: Request, res: Response, next: NextFunction): void => {
      if (!multerInstance) {
        throw new AppError(
          "La librería 'multer' no está instalada en node_modules. Ejecute 'npm install' en su terminal para habilitar la carga física de imágenes.",
          500,
        );
      }

      const middleware = multerInstance.single(fieldName);
      middleware(req, res, next);
    };
  },
};
