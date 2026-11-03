// src/controllers/auth.controller.ts
import type { Request, Response, NextFunction } from 'express';
import { authService } from '../services/auth.service';
import { UnauthorizedError } from '../core/errors';
import type {
  CreateAddressInput,
  CreateUserByAdminInput,
  ListUsersQuery,
  LoginInput,
  RefreshTokenInput,
  RegisterClientInput,
  UpdateAddressInput,
  UpdateProfileInput,
  UpdateUserStatusInput,
} from '../core/schemas/auth.schema';

export class AuthController {
  private getAuthenticatedUserId(req: Request): number {
    if (!req.user?.idUsuario) {
      throw new UnauthorizedError('Usuario no autenticado.');
    }
    return req.user.idUsuario;
  }

  // ==========================================================================
  // 1. AUTENTICACIÓN Y PERFIL (/api/auth)
  // ==========================================================================

  public register = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const body = req.body as RegisterClientInput;
      const data = await authService.registerClient(body);

      res.status(201).json({
        success: true,
        data,
        message: 'Cliente registrado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public login = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const body = req.body as LoginInput;
      const data = await authService.login(body);

      res.status(200).json({
        success: true,
        data,
        message: 'Inicio de sesión exitoso.',
      });
    } catch (error) {
      next(error);
    }
  };

  public refresh = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { refreshToken } = req.body as RefreshTokenInput;
      const data = await authService.refreshTokens(refreshToken);

      res.status(200).json({
        success: true,
        data,
        message: 'Token renovado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public logout = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { refreshToken } = (req.body ?? {}) as Partial<RefreshTokenInput>;
      await authService.logout(refreshToken);

      res.status(200).json({
        success: true,
        message: 'Sesión cerrada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public getMe = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const data = await authService.getProfile(idUsuario);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public updateMe = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as UpdateProfileInput;
      const data = await authService.updateProfile(idUsuario, body);

      res.status(200).json({
        success: true,
        data,
        message: 'Perfil actualizado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  // ==========================================================================
  // 2. ADMINISTRACIÓN DE USUARIOS (/api/users)
  // ==========================================================================

  public listUsers = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const query = req.query as unknown as ListUsersQuery;
      const data = await authService.listUsers(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public listRoles = async (_req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const data = await authService.listRoles();

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public createUserByAdmin = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuarioAdmin = this.getAuthenticatedUserId(req);
      const body = req.body as CreateUserByAdminInput;
      const data = await authService.createUserByAdmin(idUsuarioAdmin, body);

      res.status(201).json({
        success: true,
        data,
        message: 'Usuario creado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public updateUserStatus = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuarioAdmin = this.getAuthenticatedUserId(req);
      const idUsuarioObjetivo = Number(req.params.idUsuario);
      const body = req.body as UpdateUserStatusInput;

      const data = await authService.updateUserStatus(idUsuarioAdmin, idUsuarioObjetivo, body);

      res.status(200).json({
        success: true,
        data,
        message: 'Estado del usuario actualizado exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  // ==========================================================================
  // 3. DIRECCIONES DE ENTREGA (/api/addresses)
  // ==========================================================================

  public listAddresses = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const data = await authService.listAddresses(idUsuario);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public createAddress = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const body = req.body as CreateAddressInput;
      const data = await authService.createAddress(idUsuario, body);

      res.status(201).json({
        success: true,
        data,
        message: 'Dirección registrada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public updateAddress = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idDireccion = Number(req.params.idDireccion);
      const body = req.body as UpdateAddressInput;

      const data = await authService.updateAddress(idUsuario, idDireccion, body);

      res.status(200).json({
        success: true,
        data,
        message: 'Dirección actualizada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public setPrimaryAddress = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idDireccion = Number(req.params.idDireccion);

      const data = await authService.setPrimaryAddress(idUsuario, idDireccion);

      res.status(200).json({
        success: true,
        data,
        message: 'Dirección principal establecida exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };

  public deactivateAddress = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const idUsuario = this.getAuthenticatedUserId(req);
      const idDireccion = Number(req.params.idDireccion);

      const data = await authService.deactivateAddress(idUsuario, idDireccion);

      res.status(200).json({
        success: true,
        data,
        message: 'Dirección eliminada exitosamente.',
      });
    } catch (error) {
      next(error);
    }
  };
}

export const authController = new AuthController();
