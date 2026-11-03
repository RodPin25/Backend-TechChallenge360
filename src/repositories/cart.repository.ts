// src/repositories/cart.repository.ts
import { getPool, sql } from '../config/db';
import { mapSqlError } from '../core/errors';

export interface CartHeaderRecord {
  IDCarrito: number;
  IDUsuario: number | null;
  TokenInvitado: string | null;
  Estado: string;
  FechaCreacion: Date;
  FechaActualizacion: Date;
  TotalItems: number;
  TotalUnidades: number;
  Subtotal: number;
  IDCupon: number | null;
  CodigoCupon: string | null;
  CuponValido: boolean;
  MensajeCupon: string | null;
  MontoDescuento: number;
  TotalSinIVA: number;
  MontoIVA: number;
  Total: number;
}

export interface CartItemRecord {
  IDCarritoDetalle: number;
  IDCarrito: number;
  IDVariante: number;
  SKU: string;
  NombreVariante: string;
  IDProducto: number;
  NombreProducto: string;
  IDCategoria: number;
  NombreCategoria: string;
  PrecioUnitario: number;
  Cantidad: number;
  SubtotalLinea: number;
  StockFisico: number;
  StockReservado: number;
  StockDisponible: number;
  StockSuficiente: boolean;
  FechaAgregado: Date;
}

export interface CartDetailResult {
  carrito: CartHeaderRecord;
  items: CartItemRecord[];
}

export class CartRepository {
  private mapCartResult(result: { recordsets: unknown }): CartDetailResult {
    const recordsets = result.recordsets as [CartHeaderRecord[], CartItemRecord[]];
    const carrito = recordsets[0]?.[0];

    if (!carrito) {
      throw new Error('No se pudo obtener el encabezado del carrito.');
    }

    const items = recordsets[1] ?? [];
    return { carrito, items };
  }

  /**
   * 1. dbo.SP_Carrito_ObtenerDetalle
   */
  public async obtenerDetalle(params: {
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
    codigoCupon?: string | undefined;
  }): Promise<CartDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('TokenInvitado', sql.VarChar(100), params.tokenInvitado ?? null);
      request.input('CodigoCupon', sql.VarChar(30), params.codigoCupon ?? null);

      const result = await request.execute('dbo.SP_Carrito_ObtenerDetalle');
      return this.mapCartResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 2. dbo.SP_Carrito_AgregarOModificarItem
   */
  public async agregarOModificarItem(params: {
    idVariante: number;
    cantidad: number;
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
    modoOperacion: 'SUMAR' | 'FIJAR';
  }): Promise<CartDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('Cantidad', sql.Int, params.cantidad);
      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('TokenInvitado', sql.VarChar(100), params.tokenInvitado ?? null);
      request.input('ModoOperacion', sql.VarChar(15), params.modoOperacion);

      const result = await request.execute('dbo.SP_Carrito_AgregarOModificarItem');
      return this.mapCartResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 3. dbo.SP_Carrito_EliminarItem
   */
  public async eliminarItem(params: {
    idVariante: number;
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
  }): Promise<CartDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDVariante', sql.Int, params.idVariante);
      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('TokenInvitado', sql.VarChar(100), params.tokenInvitado ?? null);

      const result = await request.execute('dbo.SP_Carrito_EliminarItem');
      return this.mapCartResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 4. dbo.SP_Carrito_Vaciar
   */
  public async vaciar(params: {
    idUsuario?: number | undefined;
    tokenInvitado?: string | undefined;
  }): Promise<CartDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario ?? null);
      request.input('TokenInvitado', sql.VarChar(100), params.tokenInvitado ?? null);

      const result = await request.execute('dbo.SP_Carrito_Vaciar');
      return this.mapCartResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 5. dbo.SP_Carrito_FusionarInvitadoAUsuario
   */
  public async fusionarInvitadoAUsuario(params: {
    idUsuario: number;
    tokenInvitado: string;
  }): Promise<CartDetailResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('TokenInvitado', sql.VarChar(100), params.tokenInvitado);

      const result = await request.execute('dbo.SP_Carrito_FusionarInvitadoAUsuario');
      return this.mapCartResult(result);
    } catch (error) {
      throw mapSqlError(error);
    }
  }
}

export const cartRepository = new CartRepository();
