// src/repositories/auth.repository.ts
import { getPool, sql } from '../config/db';
import { mapSqlError } from '../core/errors';
import type { PaginatedResult } from '../core/types';

export interface UserRecord {
  IDUsuario: number;
  IDRol: number;
  NombreRol: string;
  Correo: string;
  NombreCompleto: string;
  Telefono: string | null;
  Activo: boolean;
  FechaCreacion: Date;
}

export interface UserWithPasswordRecord extends UserRecord {
  PasswordHash: string;
}

export interface RoleRecord {
  IDRol: number;
  NombreRol: string;
  Descripcion: string | null;
}

export interface AddressRecord {
  IDDireccion: number;
  IDUsuario: number;
  DireccionLinea: string;
  Municipio: string;
  Departamento: string;
  CodigoPostal: string | null;
  Referencia: string | null;
  EsPrincipal: boolean;
  Activo?: boolean;
}

export interface UserProfileResult {
  usuario: UserRecord;
  direccionPrincipal: AddressRecord | null;
}

export class AuthRepository {
  /**
   * 1. dbo.SP_Usuarios_RegistrarCliente
   */
  public async registrarCliente(params: {
    correo: string;
    passwordHash: string;
    nombreCompleto: string;
    telefono?: string | undefined;
  }): Promise<UserRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('Correo', sql.VarChar(120), params.correo);
      request.input('PasswordHash', sql.VarChar(255), params.passwordHash);
      request.input('NombreCompleto', sql.NVarChar(120), params.nombreCompleto);
      request.input('Telefono', sql.VarChar(20), params.telefono ?? null);

      const result = await request.execute<UserRecord>('dbo.SP_Usuarios_RegistrarCliente');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el registro del usuario creado.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 2. dbo.SP_Usuarios_ObtenerPorCorreo
   */
  public async obtenerPorCorreo(correo: string): Promise<UserWithPasswordRecord | null> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('Correo', sql.VarChar(120), correo);

      const result = await request.execute<UserWithPasswordRecord>(
        'dbo.SP_Usuarios_ObtenerPorCorreo',
      );

      return result.recordset?.[0] ?? null;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 3. dbo.SP_Usuarios_ObtenerPerfilPorID
   */
  public async obtenerPerfilPorID(idUsuario: number): Promise<UserProfileResult> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, idUsuario);

      const result = await request.execute('dbo.SP_Usuarios_ObtenerPerfilPorID');
      const recordsets = result.recordsets as unknown as [UserRecord[], AddressRecord[]];

      const usuario = recordsets[0]?.[0];
      if (!usuario) {
        throw new Error('No se encontró el perfil del usuario.');
      }

      const direccionPrincipal = recordsets[1]?.[0] ?? null;

      return {
        usuario,
        direccionPrincipal,
      };
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 4. dbo.SP_Usuarios_ActualizarPerfil
   */
  public async actualizarPerfil(params: {
    idUsuario: number;
    nombreCompleto: string;
    telefono?: string | undefined;
    passwordHash?: string | undefined;
  }): Promise<UserRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('NombreCompleto', sql.NVarChar(120), params.nombreCompleto);
      request.input('Telefono', sql.VarChar(20), params.telefono ?? null);
      request.input('PasswordHash', sql.VarChar(255), params.passwordHash ?? null);

      const result = await request.execute<UserRecord>('dbo.SP_Usuarios_ActualizarPerfil');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el perfil actualizado.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 5. dbo.SP_Usuarios_CrearUsuarioPorAdmin
   */
  public async crearUsuarioPorAdmin(params: {
    idUsuarioAdmin: number;
    idRol: number;
    correo: string;
    passwordHash: string;
    nombreCompleto: string;
    telefono?: string | undefined;
  }): Promise<UserRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuarioAdmin', sql.Int, params.idUsuarioAdmin);
      request.input('IDRol', sql.Int, params.idRol);
      request.input('Correo', sql.VarChar(120), params.correo);
      request.input('PasswordHash', sql.VarChar(255), params.passwordHash);
      request.input('NombreCompleto', sql.NVarChar(120), params.nombreCompleto);
      request.input('Telefono', sql.VarChar(20), params.telefono ?? null);

      const result = await request.execute<UserRecord>('dbo.SP_Usuarios_CrearUsuarioPorAdmin');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el usuario creado por el administrador.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 6. dbo.SP_Usuarios_CambiarEstadoActivo
   */
  public async cambiarEstadoActivo(params: {
    idUsuarioAdmin: number;
    idUsuarioObjetivo: number;
    activo: boolean;
    idRol?: number | undefined;
  }): Promise<UserRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuarioAdmin', sql.Int, params.idUsuarioAdmin);
      request.input('IDUsuarioObjetivo', sql.Int, params.idUsuarioObjetivo);
      request.input('Activo', sql.Bit, params.activo);
      request.input('IDRol', sql.Int, params.idRol ?? null);

      const result = await request.execute<UserRecord>('dbo.SP_Usuarios_CambiarEstadoActivo');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió el usuario actualizado.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 7. dbo.SP_Usuarios_ListarUsuarios
   */
  public async listarUsuarios(params: {
    numeroPagina: number;
    tamanoPagina: number;
    idRol?: number | undefined;
    activo?: boolean | undefined;
    busqueda?: string | undefined;
  }): Promise<PaginatedResult<UserRecord>> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('NumeroPagina', sql.Int, params.numeroPagina);
      request.input('TamanoPagina', sql.Int, params.tamanoPagina);
      request.input('IDRol', sql.Int, params.idRol ?? null);
      request.input('Activo', sql.Bit, params.activo ?? null);
      request.input('Busqueda', sql.NVarChar(120), params.busqueda ?? null);

      const result = await request.execute('dbo.SP_Usuarios_ListarUsuarios');
      const recordsets = result.recordsets as unknown as [
        Array<{ TotalRegistros: number }>,
        UserRecord[],
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
   * 8. dbo.SP_Usuarios_ListarRoles
   */
  public async listarRoles(): Promise<RoleRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      const result = await request.execute<RoleRecord>('dbo.SP_Usuarios_ListarRoles');
      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 9. dbo.SP_Direcciones_Crear
   */
  public async crearDireccion(params: {
    idUsuario: number;
    direccionLinea: string;
    municipio: string;
    departamento: string;
    codigoPostal?: string | undefined;
    referencia?: string | undefined;
    esPrincipal: boolean;
  }): Promise<AddressRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('DireccionLinea', sql.NVarChar(200), params.direccionLinea);
      request.input('Municipio', sql.NVarChar(100), params.municipio);
      request.input('Departamento', sql.NVarChar(100), params.departamento);
      request.input('CodigoPostal', sql.VarChar(10), params.codigoPostal ?? null);
      request.input('Referencia', sql.NVarChar(200), params.referencia ?? null);
      request.input('EsPrincipal', sql.Bit, params.esPrincipal);

      const result = await request.execute<AddressRecord>('dbo.SP_Direcciones_Crear');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió la dirección creada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 10. dbo.SP_Direcciones_ListarPorUsuario
   */
  public async listarDireccionesPorUsuario(idUsuario: number): Promise<AddressRecord[]> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDUsuario', sql.Int, idUsuario);

      const result = await request.execute<AddressRecord>('dbo.SP_Direcciones_ListarPorUsuario');
      return result.recordset ?? [];
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 11. dbo.SP_Direcciones_Actualizar
   */
  public async actualizarDireccion(params: {
    idDireccion: number;
    idUsuario: number;
    direccionLinea: string;
    municipio: string;
    departamento: string;
    codigoPostal?: string | undefined;
    referencia?: string | undefined;
    esPrincipal?: boolean | undefined;
  }): Promise<AddressRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDDireccion', sql.Int, params.idDireccion);
      request.input('IDUsuario', sql.Int, params.idUsuario);
      request.input('DireccionLinea', sql.NVarChar(200), params.direccionLinea);
      request.input('Municipio', sql.NVarChar(100), params.municipio);
      request.input('Departamento', sql.NVarChar(100), params.departamento);
      request.input('CodigoPostal', sql.VarChar(10), params.codigoPostal ?? null);
      request.input('Referencia', sql.NVarChar(200), params.referencia ?? null);
      request.input('EsPrincipal', sql.Bit, params.esPrincipal ?? null);

      const result = await request.execute<AddressRecord>('dbo.SP_Direcciones_Actualizar');
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió la dirección actualizada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 12. dbo.SP_Direcciones_EstablecerPrincipal
   */
  public async establecerDireccionPrincipal(
    idDireccion: number,
    idUsuario: number,
  ): Promise<AddressRecord> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDDireccion', sql.Int, idDireccion);
      request.input('IDUsuario', sql.Int, idUsuario);

      const result = await request.execute<AddressRecord>(
        'dbo.SP_Direcciones_EstablecerPrincipal',
      );
      const record = result.recordset?.[0];

      if (!record) {
        throw new Error('No se recibió la dirección principal actualizada.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }

  /**
   * 13. dbo.SP_Direcciones_Desactivar
   */
  public async desactivarDireccion(
    idDireccion: number,
    idUsuario: number,
  ): Promise<{ IDDireccionDesactivada: number; Desactivada: boolean }> {
    try {
      const pool = getPool();
      const request = pool.request();

      request.input('IDDireccion', sql.Int, idDireccion);
      request.input('IDUsuario', sql.Int, idUsuario);

      const result = await request.execute<{
        IDDireccionDesactivada: number;
        Desactivada: boolean;
      }>('dbo.SP_Direcciones_Desactivar');

      const record = result.recordset?.[0];
      if (!record) {
        throw new Error('No se pudo confirmar la desactivación de la dirección.');
      }

      return record;
    } catch (error) {
      throw mapSqlError(error);
    }
  }
}

export const authRepository = new AuthRepository();
