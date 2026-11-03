// src/services/auth.service.ts
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import jwt, { type SignOptions } from 'jsonwebtoken';
import { env } from '../config/env';
import { redisClient } from '../config/redis';
import {
  authRepository,
  type AddressRecord,
  type RoleRecord,
  type UserProfileResult,
  type UserRecord,
} from '../repositories/auth.repository';
import { ForbiddenError, UnauthorizedError } from '../core/errors';
import { ERROR_CODES } from '../core/constants';
import type { JwtUserPayload, PaginatedResult, RefreshTokenPayload } from '../core/types';
import type {
  CreateAddressInput,
  CreateUserByAdminInput,
  ListUsersQuery,
  LoginInput,
  RegisterClientInput,
  UpdateAddressInput,
  UpdateProfileInput,
  UpdateUserStatusInput,
} from '../core/schemas/auth.schema';

const BCRYPT_SALT_ROUNDS = 10;
const REFRESH_TOKEN_REDIS_TTL_SECONDS = 7 * 24 * 60 * 60; // 7 días

export interface AuthTokensResponse {
  accessToken: string;
  refreshToken: string;
  usuario: UserRecord;
}

export class AuthService {
  private buildRefreshRedisKey(idUsuario: number, jti: string): string {
    return `auth:refresh:${idUsuario}:${jti}`;
  }

  private async generateTokenPair(usuario: UserRecord): Promise<{
    accessToken: string;
    refreshToken: string;
  }> {
    const accessPayload: JwtUserPayload = {
      idUsuario: usuario.IDUsuario,
      idRol: usuario.IDRol,
      nombreRol: usuario.NombreRol,
      correo: usuario.Correo,
    };

    const accessOptions: SignOptions = {
      expiresIn: env.JWT_EXPIRES_IN as SignOptions['expiresIn'],
    };

    const accessToken = jwt.sign(accessPayload, env.JWT_SECRET, accessOptions);

    const jti = crypto.randomUUID();
    const refreshPayload: RefreshTokenPayload = {
      idUsuario: usuario.IDUsuario,
      jti,
    };

    const refreshOptions: SignOptions = {
      expiresIn: env.JWT_REFRESH_EXPIRES_IN as SignOptions['expiresIn'],
    };

    const refreshToken = jwt.sign(refreshPayload, env.JWT_REFRESH_SECRET, refreshOptions);

    // Almacenar sesión de refresh token en Redis para soportar rotación e invalidación (RF-01)
    try {
      const redisKey = this.buildRefreshRedisKey(usuario.IDUsuario, jti);
      await redisClient.set(redisKey, '1', 'EX', REFRESH_TOKEN_REDIS_TTL_SECONDS);
    } catch (err) {
      console.warn('[REDIS] No se pudo persistir el refresh token en Redis:', err);
    }

    return { accessToken, refreshToken };
  }

  /**
   * Registro de cliente nuevo (RF-01)
   */
  public async registerClient(input: RegisterClientInput): Promise<AuthTokensResponse> {
    const passwordHash = await bcrypt.hash(input.password, BCRYPT_SALT_ROUNDS);

    const usuario = await authRepository.registrarCliente({
      correo: input.correo,
      passwordHash,
      nombreCompleto: input.nombreCompleto,
      telefono: input.telefono,
    });

    const { accessToken, refreshToken } = await this.generateTokenPair(usuario);

    return {
      accessToken,
      refreshToken,
      usuario,
    };
  }

  /**
   * Inicio de sesión con validación de hash bcrypt y emisión de JWT + Refresh Token (RF-01)
   */
  public async login(input: LoginInput): Promise<AuthTokensResponse> {
    const userWithPass = await authRepository.obtenerPorCorreo(input.correo);

    if (!userWithPass) {
      throw new UnauthorizedError('Credenciales inválidas.');
    }

    if (!userWithPass.Activo) {
      throw new ForbiddenError('La cuenta de usuario se encuentra desactivada.');
    }

    const isPasswordValid = await bcrypt.compare(input.password, userWithPass.PasswordHash);

    if (!isPasswordValid) {
      throw new UnauthorizedError('Credenciales inválidas.');
    }

    const { PasswordHash: _removed, ...usuario } = userWithPass;
    const { accessToken, refreshToken } = await this.generateTokenPair(usuario);

    return {
      accessToken,
      refreshToken,
      usuario,
    };
  }

  /**
   * Rotación de Refresh Token (RF-01)
   */
  public async refreshTokens(rawRefreshToken: string): Promise<AuthTokensResponse> {
    let decoded: RefreshTokenPayload;

    try {
      decoded = jwt.verify(rawRefreshToken, env.JWT_REFRESH_SECRET) as RefreshTokenPayload;
    } catch {
      throw new UnauthorizedError(
        'El refresh token es inválido o ha expirado.',
        ERROR_CODES.TOKEN_EXPIRED,
      );
    }

    const redisKey = this.buildRefreshRedisKey(decoded.idUsuario, decoded.jti);

    try {
      const exists = await redisClient.get(redisKey);
      if (!exists) {
        throw new UnauthorizedError('El refresh token ya fue utilizado o revocado.');
      }
      // Invalidar el token anterior (rotación estricta)
      await redisClient.del(redisKey);
    } catch (error) {
      if (error instanceof UnauthorizedError) {
        throw error;
      }
      console.warn('[REDIS] Advertencia al verificar rotación de refresh token:', error);
    }

    const { usuario } = await authRepository.obtenerPerfilPorID(decoded.idUsuario);

    if (!usuario.Activo) {
      throw new ForbiddenError('La cuenta de usuario se encuentra desactivada.');
    }

    const { accessToken, refreshToken } = await this.generateTokenPair(usuario);

    return {
      accessToken,
      refreshToken,
      usuario,
    };
  }

  /**
   * Cierre de sesión revocando el Refresh Token activo
   */
  public async logout(rawRefreshToken?: string): Promise<void> {
    if (!rawRefreshToken) {
      return;
    }

    try {
      const decoded = jwt.verify(rawRefreshToken, env.JWT_REFRESH_SECRET) as RefreshTokenPayload;
      const redisKey = this.buildRefreshRedisKey(decoded.idUsuario, decoded.jti);
      await redisClient.del(redisKey);
    } catch {
      // Si el token ya expiró o es inválido, ignorar silenciosamente al cerrar sesión
    }
  }

  /**
   * Obtener perfil del usuario autenticado (/me)
   */
  public async getProfile(idUsuario: number): Promise<UserProfileResult> {
    return authRepository.obtenerPerfilPorID(idUsuario);
  }

  /**
   * Actualizar perfil del usuario autenticado (/me)
   */
  public async updateProfile(
    idUsuario: number,
    input: UpdateProfileInput,
  ): Promise<UserRecord> {
    let passwordHash: string | undefined;

    if (input.password) {
      passwordHash = await bcrypt.hash(input.password, BCRYPT_SALT_ROUNDS);
    }

    return authRepository.actualizarPerfil({
      idUsuario,
      nombreCompleto: input.nombreCompleto,
      telefono: input.telefono,
      passwordHash,
    });
  }

  /**
   * Crear usuario desde el panel de Administración
   */
  public async createUserByAdmin(
    idUsuarioAdmin: number,
    input: CreateUserByAdminInput,
  ): Promise<UserRecord> {
    const passwordHash = await bcrypt.hash(input.password, BCRYPT_SALT_ROUNDS);

    return authRepository.crearUsuarioPorAdmin({
      idUsuarioAdmin,
      idRol: input.idRol,
      correo: input.correo,
      passwordHash,
      nombreCompleto: input.nombreCompleto,
      telefono: input.telefono,
    });
  }

  /**
   * Activar/desactivar usuario o cambiar su rol (solo Administrador)
   */
  public async updateUserStatus(
    idUsuarioAdmin: number,
    idUsuarioObjetivo: number,
    input: UpdateUserStatusInput,
  ): Promise<UserRecord> {
    return authRepository.cambiarEstadoActivo({
      idUsuarioAdmin,
      idUsuarioObjetivo,
      activo: input.activo,
      idRol: input.idRol,
    });
  }

  /**
   * Listar usuarios con paginación y filtros (solo Administrador)
   */
  public async listUsers(query: ListUsersQuery): Promise<PaginatedResult<UserRecord>> {
    return authRepository.listarUsuarios({
      numeroPagina: query.numeroPagina,
      tamanoPagina: query.tamanoPagina,
      idRol: query.idRol,
      activo: query.activo,
      busqueda: query.busqueda,
    });
  }

  /**
   * Listar catálogo de roles del sistema
   */
  public async listRoles(): Promise<RoleRecord[]> {
    return authRepository.listarRoles();
  }

  /**
   * Crear dirección de entrega para el usuario autenticado
   */
  public async createAddress(
    idUsuario: number,
    input: CreateAddressInput,
  ): Promise<AddressRecord> {
    return authRepository.crearDireccion({
      idUsuario,
      direccionLinea: input.direccionLinea,
      municipio: input.municipio,
      departamento: input.departamento,
      codigoPostal: input.codigoPostal,
      referencia: input.referencia,
      esPrincipal: input.esPrincipal,
    });
  }

  /**
   * Listar direcciones del usuario autenticado
   */
  public async listAddresses(idUsuario: number): Promise<AddressRecord[]> {
    return authRepository.listarDireccionesPorUsuario(idUsuario);
  }

  /**
   * Actualizar dirección del usuario autenticado (protegido contra IDOR)
   */
  public async updateAddress(
    idUsuario: number,
    idDireccion: number,
    input: UpdateAddressInput,
  ): Promise<AddressRecord> {
    return authRepository.actualizarDireccion({
      idDireccion,
      idUsuario,
      direccionLinea: input.direccionLinea,
      municipio: input.municipio,
      departamento: input.departamento,
      codigoPostal: input.codigoPostal,
      referencia: input.referencia,
      esPrincipal: input.esPrincipal,
    });
  }

  /**
   * Establecer dirección como principal
   */
  public async setPrimaryAddress(
    idUsuario: number,
    idDireccion: number,
  ): Promise<AddressRecord> {
    return authRepository.establecerDireccionPrincipal(idDireccion, idUsuario);
  }

  /**
   * Desactivar dirección del usuario autenticado
   */
  public async deactivateAddress(
    idUsuario: number,
    idDireccion: number,
  ): Promise<{ IDDireccionDesactivada: number; Desactivada: boolean }> {
    return authRepository.desactivarDireccion(idDireccion, idUsuario);
  }
}

export const authService = new AuthService();
