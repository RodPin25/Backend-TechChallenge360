// src/controllers/reports.controller.ts
import type { Request, Response, NextFunction } from 'express';
import { reportsService } from '../services/reports.service';
import type {
  AbandonedCartsQuery,
  ConsultAuditLogQuery,
  DashboardKpisQuery,
  SalesByCategoryQuery,
  SalesByPeriodQuery,
  TopProductsQuery,
} from '../core/schemas/reports.schema';

export class ReportsController {
  public getKpis = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const query = req.query as unknown as DashboardKpisQuery;
      const data = await reportsService.getDashboardKpis(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public getSalesByPeriod = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const query = req.query as unknown as SalesByPeriodQuery;
      const data = await reportsService.getSalesByPeriod(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public getSalesByCategory = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const query = req.query as unknown as SalesByCategoryQuery;
      const data = await reportsService.getSalesByCategory(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public getTopProducts = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const query = req.query as unknown as TopProductsQuery;
      const data = await reportsService.getTopProducts(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public listAbandonedCarts = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const query = req.query as unknown as AbandonedCartsQuery;
      const data = await reportsService.listAbandonedCarts(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };

  public consultAuditLog = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const query = req.query as unknown as ConsultAuditLogQuery;
      const data = await reportsService.consultAuditLog(query);

      res.status(200).json({
        success: true,
        data,
      });
    } catch (error) {
      next(error);
    }
  };
}

export const reportsController = new ReportsController();
