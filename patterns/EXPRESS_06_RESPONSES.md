# Express.js - Pagination & Responses

Patterns for pagination and response formatting.

---

## Pagination Helpers

```typescript
// src/controllers/base.controller.ts

import { Request, Response, NextFunction } from "express";
import { PaginationMeta } from "@your-package/shared-library";

export abstract class BaseController {
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
   * Build pagination metadata
   */
  protected buildPaginationMeta(total: number, page: number, limit: number): PaginationMeta {
    const totalPages = Math.ceil(total / limit);
    return {
      page,
      pageSize: limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    };
  }

  /**
   * Send paginated response using standardized format
   */
  protected sendPaginatedResponse<T>(
    res: Response,
    data: T[],
    total: number,
    page: number,
    limit: number
  ): void {
    res.json({
      success: true,
      data,
      pagination: this.buildPaginationMeta(total, page, limit),
    });
  }
}
```

---

## Response Helpers

```typescript
export abstract class BaseController {
  // ... pagination methods above ...

  /**
   * Send success response with data
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

---

## Response Utilities

```typescript
// src/utils/response.utils.ts

import { Response } from "express";
import { ApiResponse, PaginationMeta } from "@your-package/shared-library";

/**
 * Send successful response with data
 */
export function sendSuccess<T>(
  res: Response,
  data: T,
  statusCode: number = 200,
  pagination?: PaginationMeta
): void {
  const response: ApiResponse<T> = { success: true, data };
  if (pagination) {
    response.pagination = pagination;
  }
  res.status(statusCode).json(response);
}

/**
 * Send error response
 */
export function sendError(
  res: Response,
  message: string,
  statusCode: number = 500,
  code?: string,
  details?: unknown
): void {
  const response: ApiResponse = {
    success: false,
    error: {
      message,
      code: code || "INTERNAL_ERROR",
      timestamp: new Date().toISOString(),
      ...(details && { details }),
    },
  };
  res.status(statusCode).json(response);
}

/**
 * Send created response (201)
 */
export function sendCreated<T>(res: Response, data: T): void {
  sendSuccess(res, data, 201);
}

/**
 * Send no content response (204)
 */
export function sendNoContent(res: Response): void {
  res.status(204).send();
}
```

---

## Usage in Controllers

```typescript
// src/controllers/users.controller.ts

export class UsersController extends BaseController {
  /**
   * List users (paginated)
   * GET /api/users
   */
  list = this.handleAsync(async (req: Request, res: Response): Promise<void> => {
    const { page, limit, offset } = this.getPagination(req);

    const userRepo = this.db.getUserRepository();
    const result = await userRepo.list(offset, limit);

    this.sendPaginatedResponse(res, result.items, result.total, page, limit);
  });
}
```
