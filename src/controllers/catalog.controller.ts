// src/controllers/catalog.controller.ts
import type { Request, Response, NextFunction } from 'express';
import { catalogService } from '../services/catalog.service';
import { UnauthorizedError } from '../core/errors';
import { ROLE_NAMES, ROLES } from '../core/constants';
import type {
  CreateCategoryInput,
  CreateProductInput,
  CreateVariantInput,
  ListCategoriesQuery,
  ListProductsQuery,
  PriceHistoryQuery,
  ProductDetailQuery,
  SaveVariantAttributeInput,
  UpdateCategoryInput,
  UpdateProductInput,
  UpdateProductStatusInput,
  UpdateVariantInput,
} from '../core/schemas/catalog.schema';

export class CatalogController {
  private getAuthenticatedUserId(req: Request): number {
    if (!req.user?.idUsuario) {
      throw new UnauthorizedError('Usuario no autenticado.');
    }
    return req.user.idUsuario;
  }

  private isStaffOrAdmin(req: Request): boolean {
    if (!req.user) {
      return false;
    }
    return (
      req.user.idRol === ROLES.ADMIN ||
      req.user.idRol === ROLES.OPERADOR ||
      req.user.nombreRol === ROLE_NAMES.ADMIN ||
      req.user.nombreRol === ROLE_NAMES.OPERADOR
    );
  }

  // ==========================================================================
  // 1. CATEGORÍAS
  // ==========================================================================

  public listCategories = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const query = req.query as unknown as ListCategoriesQuery;
      // Solo Administrador u Operador pueden solicitar categorías inactivas
      const soloActivas = this.isStaffOrAdmin(req) ? query.soloActivas : true;
      const data = await catalogService.listCategories(soloActivas);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public createCategory = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as CreateCategoryInput;
      const data = await catalogService.createCategory(idUsuario, body);

      res.status(201).json({
        success: true,
        data,
        message: 'Categoría creada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public updateCategory = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idCategoria = Number(req.params.idCategoria);
      const body = req.body as UpdateCategoryInput;

      const data = await catalogService.updateCategory(idUsuario, idCategoria, body);

      res.status(200).json({
        success: true,
        data,
        message: 'Categoría actualizada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  // ==========================================================================
  // 2. PRODUCTOS
  // ==========================================================================

  public listProducts = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const query = req.query as unknown as ListProductsQuery;
      // Clientes o visitantes solo pueden ver productos activos en la tienda (RF-02)
      const soloActivos = this.isStaffOrAdmin(req) ? query.soloActivos : true;

      const data = await catalogService.listProducts({
        ...query,
        soloActivos,
      });

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public getProductDetail = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idProducto = Number(req.params.idProducto);
      const query = req.query as unknown as ProductDetailQuery;
      const incluirInactivos = this.isStaffOrAdmin(req) ? query.incluirInactivos : false;

      const data = await catalogService.getProductDetail(idProducto, incluirInactivos);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public createProduct = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as CreateProductInput;
      const data = await catalogService.createProduct(idUsuario, body);

      res.status(201).json({
        success: true,
        data,
        message: 'Producto creado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public updateProduct = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idProducto = Number(req.params.idProducto);
      const body = req.body as UpdateProductInput;

      const data = await catalogService.updateProduct(idUsuario, idProducto, body);

      res.status(200).json({
        success: true,
        data,
        message: 'Producto actualizado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public updateProductStatus = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idProducto = Number(req.params.idProducto);
      const body = req.body as UpdateProductStatusInput;

      const data = await catalogService.updateProductStatus(idUsuario, idProducto, body);

      res.status(200).json({
        success: true,
        data,
        message: body.activo
          ? 'Producto activado exitosamente.'
          : 'Producto desactivado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  // ==========================================================================
  // 3. VARIANTES, ATRIBUTOS E HISTORIAL DE PRECIOS
  // ==========================================================================

  public createVariant = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idProducto = Number(req.params.idProducto);
      const body = req.body as CreateVariantInput;

      const data = await catalogService.createVariant(idUsuario, idProducto, body);

      res.status(201).json({
        success: true,
        data,
        message: 'Variante creada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public updateVariant = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idVariante = Number(req.params.idVariante);
      const body = req.body as UpdateVariantInput;

      const data = await catalogService.updateVariant(idUsuario, idVariante, body);

      res.status(200).json({
        success: true,
        data,
        message: 'Variante actualizada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public saveVariantAttribute = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idVariante = Number(req.params.idVariante);
      const body = req.body as SaveVariantAttributeInput;

      const data = await catalogService.saveVariantAttribute(idVariante, body);

      res.status(200).json({
        success: true,
        data,
        message: 'Atributo de variante guardado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public deleteVariantAttribute = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idVariante = Number(req.params.idVariante);
      const idVarianteAtributo = Number(req.params.idVarianteAtributo);

      const data = await catalogService.deleteVariantAttribute(idVarianteAtributo, idVariante);

      res.status(200).json({
        success: true,
        data,
        message: 'Atributo de variante eliminado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public getPriceHistory = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const query = req.query as unknown as PriceHistoryQuery;
      const data = await catalogService.getPriceHistory(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };
}

export const catalogController = new CatalogController();
