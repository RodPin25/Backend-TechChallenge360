// src/services/catalog.service.ts
import { redisClient } from '../config/redis';
import {
  catalogRepository,
  type CategoryRecord,
  type PriceHistoryRecord,
  type ProductDetailResult,
  type ProductListItemRecord,
  type ProductMasterRecord,
  type VariantAttributeRecord,
  type VariantRecord,
} from '../repositories/catalog.repository';
import type { PaginatedResult } from '../core/types';
import type {
  CreateCategoryInput,
  CreateProductInput,
  CreateVariantInput,
  ListProductsQuery,
  PriceHistoryQuery,
  SaveVariantAttributeInput,
  UpdateCategoryInput,
  UpdateProductInput,
  UpdateProductStatusInput,
  UpdateVariantInput,
} from '../core/schemas/catalog.schema';

const CATEGORIES_CACHE_TTL_SECONDS = 600; // 10 minutos
const CATEGORIES_ACTIVE_KEY = 'catalogo:categorias:activas';
const CATEGORIES_ALL_KEY = 'catalogo:categorias:todas';

export class CatalogService {
  /**
   * Invalida las claves de caché de categorías en Redis tras cualquier operación de escritura en catálogo.
   * Nota: Los listados y detalles con StockDisponible real siempre se resuelven en SQL Server
   * para respetar estrictamente la prohibición de cachear inventario transaccional en Redis.
   */
  public async invalidateCatalogCache(): Promise<void> {
    try {
      await redisClient.del(CATEGORIES_ACTIVE_KEY, CATEGORIES_ALL_KEY);
    } catch (error) {
      console.warn('[REDIS] No se pudo invalidar el caché de catálogo:', error);
    }
  }

  // ==========================================================================
  // 1. CATEGORÍAS (Con Patrón Cache-Aside en Redis)
  // ==========================================================================

  public async listCategories(soloActivas: boolean): Promise<CategoryRecord[]> {
    const cacheKey = soloActivas ? CATEGORIES_ACTIVE_KEY : CATEGORIES_ALL_KEY;

    try {
      const cached = await redisClient.get(cacheKey);
      if (cached) {
        return JSON.parse(cached) as CategoryRecord[];
      }
    } catch (error) {
      console.warn('[REDIS] Error al leer caché de categorías:', error);
    }

    const categories = await catalogRepository.listarCategorias(soloActivas);

    try {
      await redisClient.set(
        cacheKey,
        JSON.stringify(categories),
        'EX',
        CATEGORIES_CACHE_TTL_SECONDS,
      );
    } catch (error) {
      console.warn('[REDIS] Error al guardar caché de categorías:', error);
    }

    return categories;
  }

  public async createCategory(
    idUsuario: number,
    input: CreateCategoryInput,
  ): Promise<CategoryRecord> {
    const category = await catalogRepository.crearCategoria({
      idUsuario,
      nombreCategoria: input.nombreCategoria,
      descripcion: input.descripcion,
    });

    await this.invalidateCatalogCache();
    return category;
  }

  public async updateCategory(
    idUsuario: number,
    idCategoria: number,
    input: UpdateCategoryInput,
  ): Promise<CategoryRecord> {
    const category = await catalogRepository.actualizarCategoria({
      idUsuario,
      idCategoria,
      nombreCategoria: input.nombreCategoria,
      descripcion: input.descripcion,
      activo: input.activo,
    });

    await this.invalidateCatalogCache();
    return category;
  }

  // ==========================================================================
  // 2. PRODUCTOS
  // ==========================================================================

  public async listProducts(
    query: ListProductsQuery,
  ): Promise<PaginatedResult<ProductListItemRecord>> {
    return catalogRepository.listarProductos({
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      busqueda: query.busqueda,
      idCategoria: query.idCategoria,
      precioMinimo: query.precioMinimo,
      precioMaximo: query.precioMaximo,
      soloDisponibles: query.soloDisponibles,
      soloActivos: query.soloActivos,
      ordenarPor: query.ordenarPor,
    });
  }

  public async getProductDetail(
    idProducto: number,
    incluirInactivos: boolean,
  ): Promise<ProductDetailResult> {
    return catalogRepository.obtenerDetalleProducto(idProducto, incluirInactivos);
  }

  public async createProduct(
    idUsuario: number,
    input: CreateProductInput,
  ): Promise<ProductMasterRecord> {
    const product = await catalogRepository.crearProducto({
      idUsuario,
      idCategoria: input.idCategoria,
      nombreProducto: input.nombreProducto,
      descripcion: input.descripcion,
    });

    await this.invalidateCatalogCache();
    return product;
  }

  public async updateProduct(
    idUsuario: number,
    idProducto: number,
    input: UpdateProductInput,
  ): Promise<ProductMasterRecord> {
    const product = await catalogRepository.actualizarProducto({
      idUsuario,
      idProducto,
      idCategoria: input.idCategoria,
      nombreProducto: input.nombreProducto,
      descripcion: input.descripcion,
    });

    await this.invalidateCatalogCache();
    return product;
  }

  public async updateProductStatus(
    idUsuario: number,
    idProducto: number,
    input: UpdateProductStatusInput,
  ): Promise<{ IDProducto: number; NombreProducto: string; Activo: boolean }> {
    const result = await catalogRepository.cambiarEstadoProducto({
      idUsuario,
      idProducto,
      activo: input.activo,
    });

    await this.invalidateCatalogCache();
    return result;
  }

  // ==========================================================================
  // 3. VARIANTES, ATRIBUTOS E HISTORIAL DE PRECIOS
  // ==========================================================================

  public async createVariant(
    idUsuario: number,
    idProducto: number,
    input: CreateVariantInput,
  ): Promise<VariantRecord> {
    return catalogRepository.crearVariante({
      idUsuario,
      idProducto,
      sku: input.sku,
      nombreVariante: input.nombreVariante,
      precio: input.precio,
      stockInicial: input.stockInicial,
    });
  }

  public async updateVariant(
    idUsuario: number,
    idVariante: number,
    input: UpdateVariantInput,
  ): Promise<VariantRecord> {
    return catalogRepository.actualizarVariante({
      idUsuario,
      idVariante,
      sku: input.sku,
      nombreVariante: input.nombreVariante,
      precio: input.precio,
      activo: input.activo,
    });
  }

  public async saveVariantAttribute(
    idVariante: number,
    input: SaveVariantAttributeInput,
  ): Promise<VariantAttributeRecord> {
    return catalogRepository.guardarAtributoVariante({
      idVariante,
      clave: input.clave,
      valor: input.valor,
    });
  }

  public async deleteVariantAttribute(
    idVarianteAtributo: number,
    idVariante: number,
  ): Promise<VariantAttributeRecord[]> {
    return catalogRepository.eliminarAtributoVariante(idVarianteAtributo, idVariante);
  }

  public async getPriceHistory(query: PriceHistoryQuery): Promise<PriceHistoryRecord[]> {
    return catalogRepository.obtenerHistorialPrecios({
      idVariante: query.idVariante,
      idProducto: query.idProducto,
    });
  }
}

export const catalogService = new CatalogService();
