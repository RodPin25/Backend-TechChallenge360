// src/repositories/catalog.repository.ts
import { getPool, sql } from '../config/db';
import { mapSqlError } from '../core/errors';
import type { PaginatedResult } from '../core/types';

export interface CategoryRecord {
  IDCategoria: number;
  NombreCategoria: string;
  Descripcion: string | null;
  Activo: boolean;
  TotalProductosActivos?: number;
}

export interface ProductMasterRecord {
  IDProducto: number;
  IDCategoria: number;
  NombreCategoria: string;
  NombreProducto: string;
  Descripcion: string | null;
  Activo: boolean;
  FechaCreacion: Date;
}

export interface ProductListItemRecord extends ProductMasterRecord {
  TotalVariantesActivas: number;
  PrecioDesde: number;
  PrecioHasta: number;
  PrecioDesdeSinIVA: number;
  PrecioDesdeIVA: number;
  StockFisicoTotal: number;
  StockDisponibleTotal: number;
  TieneDisponibilidad: boolean;
  ImagenPortada?: string | null;
}

export interface VariantAttributeRecord {
  IDVarianteAtributo: number;
  IDVariante: number;
  Clave: string;
  Valor: string;
  Activo: boolean;
}

export interface VariantImageRecord {
  IDVarianteImagen: number;
  IDVariante: number;
  UrlImagen: string;
  EsPrincipal: boolean;
  Orden: number;
  Activo: boolean;
  FechaCreacion?: Date;
}

export interface VariantRecord {
  IDVariante: number;
  IDProducto: number;
  SKU: string;
  NombreVariante: string;
  Precio: number;
  PrecioSinIVA?: number;
  MontoIVAUnitario?: number;
  StockFisico: number;
  StockReservado: number;
  StockDisponible: number;
  Activo: boolean;
  ImagenPrincipal?: string | null;
  atributos?: VariantAttributeRecord[];
  imagenes?: VariantImageRecord[];
}

export interface ProductDetailResult {
  producto: ProductMasterRecord;
  variantes: VariantRecord[];
}

export interface PriceHistoryRecord {
  IDHistorialPrecio: number;
  IDVariante: number;
  SKU: string;
  NombreVariante: string;
  IDProducto: number;
  NombreProducto: string;
  PrecioAnterior: number;
  PrecioNuevo: number;
  IDUsuario: number;
  ModificadoPor: string;
  CorreoModificador: string;
  FechaModificacion: Date;
}

export class CatalogRepository {
  /**
   * 1. dbo.SP_Catalogo_CrearCategoria
   */
  public async crearCategoria(params: {
    idUsuario: number;
    nombreCategoria: string;
    descripcion?: string | undefined;
  }): Promise<CategoryRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('NombreCategoria', sql.NVarChar(100), params.nombreCategoria);
      request.input('Descripcion', sql.NVarChar(250), params.descripcion ?? null);

      const result = await request.execute<CategoryRecord>('dbo.SP_Catalogo_CrearCategoria');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió la categoría creada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 2. dbo.SP_Catalogo_ActualizarCategoria
   */
  public async actualizarCategoria(params: {
    idUsuario: number;
    idCategoria: number;
    nombreCategoria: string;
    descripcion?: string | undefined;
    activo: boolean;
  }): Promise<CategoryRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDCategoria', sql.Int, params.idCategoria);
      request.input('NombreCategoria', sql.NVarChar(100), params.nombreCategoria);
      request.input('Descripcion', sql.NVarChar(250), params.descripcion ?? null);
      request.input('Activo', sql.Bit, params.activo);

      const result = await request.execute<CategoryRecord>('dbo.SP_Catalogo_ActualizarCategoria');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió la categoría actualizada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 3. dbo.SP_Catalogo_ListarCategorias
   */
  public async listarCategorias(soloActivas: boolean): Promise<CategoryRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('SoloActivas', sql.Bit, soloActivas);

      const result = await request.execute<CategoryRecord>('dbo.SP_Catalogo_ListarCategorias');
      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 4. dbo.SP_Catalogo_CrearProducto
   */
  public async crearProducto(params: {
    idUsuario: number;
    idCategoria: number;
    nombreProducto: string;
    descripcion?: string | undefined;
  }): Promise<ProductMasterRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDCategoria', sql.Int, params.idCategoria);
      request.input('NombreProducto', sql.NVarChar(150), params.nombreProducto);
      request.input('Descripcion', sql.NVarChar(sql.MAX), params.descripcion ?? null);

      const result = await request.execute<ProductMasterRecord>('dbo.SP_Catalogo_CrearProducto');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el producto creado.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 5. dbo.SP_Catalogo_ActualizarProducto
   */
  public async actualizarProducto(params: {
    idUsuario: number;
    idProducto: number;
    idCategoria: number;
    nombreProducto: string;
    descripcion?: string | undefined;
  }): Promise<ProductMasterRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDProducto', sql.Int, params.idProducto);
      request.input('IDCategoria', sql.Int, params.idCategoria);
      request.input('NombreProducto', sql.NVarChar(150), params.nombreProducto);
      request.input('Descripcion', sql.NVarChar(sql.MAX), params.descripcion ?? null);

      const result = await request.execute<ProductMasterRecord>(
        'dbo.SP_Catalogo_ActualizarProducto',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el producto actualizado.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 6. dbo.SP_Catalogo_CambiarEstadoProducto
   */
  public async cambiarEstadoProducto(params: {
    idUsuario: number;
    idProducto: number;
    activo: boolean;
  }): Promise<{ IDProducto: number; NombreProducto: string; Activo: boolean }> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDProducto', sql.Int, params.idProducto);
      request.input('Activo', sql.Bit, params.activo);

      const result = await request.execute<{
        IDProducto: number;
        NombreProducto: string;
        Activo: boolean;
      }>('dbo.SP_Catalogo_CambiarEstadoProducto');

      const record = result.recordset?.[0];
      if (!record) {
        throw new Error('No se recibió el estado actualizado del producto.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 7. dbo.SP_Catalogo_ListarProductos
   */
  public async listarProductos(params: {
    numeroPagina: number;
    tamanoPagina: number;
    busqueda?: string | undefined;
    idCategoria?: number | undefined;
    precioMinimo?: number | undefined;
    precioMaximo?: number | undefined;
    soloDisponibles: boolean;
    soloActivos: boolean;
    ordenarPor: string;
  }): Promise<PaginatedResult<ProductListItemRecord>> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('Busqueda', sql.NVarChar(150), params.busqueda ?? null);
      request.input('IDCategoria', sql.Int, params.idCategoria ?? null);
      request.input(
        'PrecioMinimo',
        sql.Decimal(12, 2),
        params.precioMinimo !== undefined ? Number(params.precioMinimo.toFixed(2)) : null,
      );
      request.input(
        'PrecioMaximo',
        sql.Decimal(12, 2),
        params.precioMaximo !== undefined ? Number(params.precioMaximo.toFixed(2)) : null,
      );
      request.input('SoloDisponibles', sql.Bit, params.soloDisponibles);
      request.input('SoloActivos', sql.Bit, params.soloActivos);
      request.input('OrdenarPor', sql.VarChar(30), params.ordenarPor);

      const result = await request.execute('dbo.SP_Catalogo_ListarProductos');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number }>,
        ProductListItemRecord[],
      ];

      const totalRegistros = recordsets[0]?.[0]?.TotalRegistros ?? 0;
      const items = recordsets[1] ?? [];
      const totalPaginas = Math.ceil(totalRegistros / params.tamanoPagina);

      return {
        items,
        totalRegistros,
        numeroPagina: params.numeroPagina,
        tamanoPagina: params.tamanoPagina,
        totalPaginas,
      };
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 8. dbo.SP_Catalogo_ObtenerDetalleProducto
   * Devuelve 4 recordsets: Producto, Variantes, Atributos de cada variante y Galería de Imágenes.
   */
  public async obtenerDetalleProducto(
    idProducto: number,
    incluirInactivos: boolean,
  ): Promise<ProductDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDProducto', sql.Int, idProducto);
      request.input('IncluirInactivos', sql.Bit, incluirInactivos);

      const result = await request.execute('dbo.SP_Catalogo_ObtenerDetalleProducto');
      const recordsets = result.recordsets as unknown as [
        ProductMasterRecord[],
        VariantRecord[],
        VariantAttributeRecord[],
        VariantImageRecord[],
      ];

      const producto = recordsets[0]?.[0];
      if (!producto) {
        throw new Error('El producto solicitado no fue encontrado.');
      }

      const rawVariantes = recordsets[1] ?? [];
      const rawAtributos = recordsets[2] ?? [];
      const rawImagenes = recordsets[3] ?? [];

      // Agrupar atributos por IDVariante para entregar una estructura jerárquica limpia
      const atributosPorVariante = new Map<number, VariantAttributeRecord[]>();
      for (const attr of rawAtributos) {
        const list = atributosPorVariante.get(attr.IDVariante) ?? [];
        list.push(attr);
        atributosPorVariante.set(attr.IDVariante, list);
      }

      // Agrupar imágenes por IDVariante para la galería completa
      const imagenesPorVariante = new Map<number, VariantImageRecord[]>();
      for (const img of rawImagenes) {
        const list = imagenesPorVariante.get(img.IDVariante) ?? [];
        list.push(img);
        imagenesPorVariante.set(img.IDVariante, list);
      }

      const variantes: VariantRecord[] = rawVariantes.map((v) => ({
        ...v,
        atributos: atributosPorVariante.get(v.IDVariante) ?? [],
        imagenes: imagenesPorVariante.get(v.IDVariante) ?? [],
      }));

      return {
        producto,
        variantes,
      };
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 9. dbo.SP_Catalogo_CrearVariante
   */
  public async crearVariante(params: {
    idUsuario: number;
    idProducto: number;
    sku: string;
    nombreVariante: string;
    precio: number;
    stockInicial: number;
  }): Promise<VariantRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDProducto', sql.Int, params.idProducto);
      request.input('SKU', sql.VarChar(50), params.sku);
      request.input('NombreVariante', sql.NVarChar(100), params.nombreVariante);
      request.input('Precio', sql.Decimal(12, 2), Number(params.precio.toFixed(2)));
      request.input('StockInicial', sql.Int, params.stockInicial);

      const result = await request.execute<VariantRecord>('dbo.SP_Catalogo_CrearVariante');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió la variante creada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 10. dbo.SP_Catalogo_ActualizarVariante
   */
  public async actualizarVariante(params: {
    idUsuario: number;
    idVariante: number;
    sku: string;
    nombreVariante: string;
    precio: number;
    activo: boolean;
  }): Promise<VariantRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('SKU', sql.VarChar(50), params.sku);
      request.input('NombreVariante', sql.NVarChar(100), params.nombreVariante);
      request.input('Precio', sql.Decimal(12, 2), Number(params.precio.toFixed(2)));
      request.input('Activo', sql.Bit, params.activo);

      const result = await request.execute<VariantRecord>('dbo.SP_Catalogo_ActualizarVariante');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió la variante actualizada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 11. dbo.SP_Catalogo_GuardarAtributoVariante
   */
  public async guardarAtributoVariante(params: {
    idVariante: number;
    clave: string;
    valor: string;
  }): Promise<VariantAttributeRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('Clave', sql.NVarChar(50), params.clave);
      request.input('Valor', sql.NVarChar(100), params.valor);

      const result = await request.execute<VariantAttributeRecord>(
        'dbo.SP_Catalogo_GuardarAtributoVariante',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el atributo guardado.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 12. dbo.SP_Catalogo_EliminarAtributoVariante
   */
  public async eliminarAtributoVariante(
    idVarianteAtributo: number,
    idVariante: number,
  ): Promise<VariantAttributeRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDVarianteAtributo', sql.Int, idVarianteAtributo);
      request.input('IDVariante', sql.Int, idVariante);

      const result = await request.execute<VariantAttributeRecord>(
        'dbo.SP_Catalogo_EliminarAtributoVariante',
      );

      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 13. dbo.SP_Catalogo_ObtenerHistorialPrecios
   */
  public async obtenerHistorialPrecios(params: {
    idVariante?: number | undefined;
    idProducto?: number | undefined;
  }): Promise<PriceHistoryRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDVariante', sql.Int, params.idVariante ?? null);
      request.input('IDProducto', sql.Int, params.idProducto ?? null);

      const result = await request.execute<PriceHistoryRecord>(
        'dbo.SP_Catalogo_ObtenerHistorialPrecios',
      );

      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 14. dbo.SP_Catalogo_AgregarImagenVariante
   */
  public async agregarImagenVariante(params: {
    idUsuario: number;
    idVariante: number;
    urlImagen: string;
    esPrincipal?: boolean;
    orden?: number;
  }): Promise<VariantImageRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('UrlImagen', sql.NVarChar(500), params.urlImagen);
      request.input('EsPrincipal', sql.Bit, params.esPrincipal ?? false);
      request.input('Orden', sql.Int, params.orden ?? null);

      const result = await request.execute<VariantImageRecord>(
        'dbo.SP_Catalogo_AgregarImagenVariante',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió la imagen de variante creada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 15. dbo.SP_Catalogo_EstablecerImagenPrincipalVariante
   */
  public async establecerImagenPrincipalVariante(params: {
    idUsuario: number;
    idVariante: number;
    idVarianteImagen: number;
  }): Promise<VariantImageRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('IDVarianteImagen', sql.Int, params.idVarianteImagen);

      const result = await request.execute<VariantImageRecord>(
        'dbo.SP_Catalogo_EstablecerImagenPrincipalVariante',
      );

      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 16. dbo.SP_Catalogo_EliminarImagenVariante
   */
  public async eliminarImagenVariante(params: {
    idUsuario: number;
    idVariante: number;
    idVarianteImagen: number;
  }): Promise<VariantImageRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('IDVarianteImagen', sql.Int, params.idVarianteImagen);

      const result = await request.execute<VariantImageRecord>(
        'dbo.SP_Catalogo_EliminarImagenVariante',
      );

      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }
}

export const catalogRepository = new CatalogRepository();
