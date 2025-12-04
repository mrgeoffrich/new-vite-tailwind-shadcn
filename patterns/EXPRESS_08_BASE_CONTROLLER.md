# Express.js - Base Controller Pattern

A reusable base controller class with common helpers.

---

## Base Controller

```typescript
// src/controllers/base.controller.ts

import { Request, Response, NextFunction } from "express";
import { DatabaseService, getDatabaseService } from "../services/database.service.js";
import { getChildLogger } from "../utils/logger.js";

export abstract class BaseController {
  protected db: DatabaseService;
  protected logger;

  constructor() {
    this.db = getDatabaseService();
    this.logger = getChildLogger({ controller: this.constructor.name });
  }

  /**
   * Wrap async handlers to catch errors and forward to error middleware
   */
  protected handleAsync(
    fn: (req: Request, res: Response, next: NextFunction) => Promise<void>
  ) {
    return (req: Request, res: Response, next: NextFunction) => {
      Promise.resolve(fn(req, res, next)).catch(next);
    };
  }

  /**
   * Extract pagination parameters from request
   */
  protected getPagination(req: Request): { page: number; limit: number; offset: number } {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 20));
    const offset = (page - 1) * limit;

    return { page, limit, offset };
  }

  /**
   * Send paginated response
   */
  protected sendPaginatedResponse<T>(
    res: Response,
    data: T[],
    total: number,
    page: number,
    limit: number
  ): void {
    const totalPages = Math.ceil(total / limit);

    res.json({
      success: true,
      data,
      pagination: {
        page,
        pageSize: limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
    });
  }

  /**
   * Send success response
   */
  protected sendSuccess<T>(res: Response, data: T, statusCode: number = 200): void {
    res.status(statusCode).json({
      success: true,
      data,
    });
  }

  /**
   * Send created response (201)
   */
  protected sendCreated<T>(res: Response, data: T): void {
    this.sendSuccess(res, data, 201);
  }

  /**
   * Send no content response (204)
   */
  protected sendNoContent(res: Response): void {
    res.status(204).send();
  }

  /**
   * Send error response
   */
  protected sendError(res: Response, message: string, code: string, statusCode: number = 400): void {
    res.status(statusCode).json({
      success: false,
      error: {
        message,
        code,
        timestamp: new Date().toISOString(),
      },
    });
  }

  /**
   * Send not found error
   */
  protected sendNotFound(res: Response, resource: string = "Resource"): void {
    this.sendError(res, `${resource} not found`, "NOT_FOUND", 404);
  }

  /**
   * Send unauthorized error
   */
  protected sendUnauthorized(res: Response, message: string = "Unauthorized"): void {
    this.sendError(res, message, "UNAUTHORIZED", 401);
  }

  /**
   * Send forbidden error
   */
  protected sendForbidden(res: Response, message: string = "Access denied"): void {
    this.sendError(res, message, "FORBIDDEN", 403);
  }
}
```
