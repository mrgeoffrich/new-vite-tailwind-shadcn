# Express.js Route Patterns Guide

A comprehensive guide to building robust Express.js APIs, extracted from a production TypeScript monorepo.

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Shared Types](#2-shared-types)
3. [Route Organization](#3-route-organization)
4. [Authentication Middleware](#4-authentication-middleware)
5. [Request Validation with Zod](#5-request-validation-with-zod)
6. [Error Handling](#6-error-handling)
7. [Pagination](#7-pagination)
8. [Response Formatting](#8-response-formatting)
9. [Rate Limiting](#9-rate-limiting)
10. [Logging Middleware](#10-logging-middleware)
11. [Base Controller Pattern](#11-base-controller-pattern)
12. [Complete Example](#12-complete-example)

---

## 1. Project Structure

```
src/
├── app.ts                           # Express app setup & middleware stack
├── routes/
│   ├── index.ts                     # Route registration
│   ├── users.routes.ts              # User routes
│   └── auth.routes.ts               # Auth routes
├── middleware/
│   ├── auth.middleware.ts           # Authentication strategies
│   ├── error.middleware.ts          # Error handling
│   ├── validation.middleware.ts     # Request validation
│   ├── rate-limit.middleware.ts     # Rate limiting
│   └── logging.middleware.ts        # Request/response logging
├── controllers/
│   ├── base.controller.ts           # Base class with helpers
│   └── users.controller.ts          # User controller
├── utils/
│   └── response.utils.ts            # Response formatting
└── types/
    └── express.d.ts                 # Express type extensions

shared-library/
├── types/
│   ├── pagination.ts                # Pagination types
│   └── api-response.ts              # API response types
├── errors/
│   ├── base-error.ts                # Base error class
│   └── application-errors.ts        # Specialized errors
└── validation/
    └── schemas.ts                   # Shared Zod schemas
```

---

## 2. Shared Types

### Pagination Types

```typescript
// shared-library/types/pagination.ts

/**
 * Pagination metadata included in all paginated API responses
 */
export interface PaginationMeta {
  /** Current page number (1-based) */
  page: number;
  /** Number of items per page */
  pageSize: number;
  /** Total number of items across all pages */
  total: number;
  /** Total number of pages */
  totalPages: number;
  /** Whether there is a next page */
  hasNext: boolean;
  /** Whether there is a previous page */
  hasPrev: boolean;
}

/**
 * Generic paginated response wrapper
 */
export interface PaginatedResponse<T> {
  data: T[];
  pagination: PaginationMeta;
}

/**
 * Pagination parameters for API requests
 */
export interface PaginationParams {
  /** Page number (1-based, default: 1) */
  page?: number;
  /** Number of items per page (default: 20, max: 100) */
  limit?: number;
}
```

### API Response Types

```typescript
// shared-library/types/api-response.ts

/**
 * Standard API response wrapper
 */
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: ApiErrorResponse;
  pagination?: PaginationMeta;
}

/**
 * Helper type for successful responses
 */
export interface SuccessResponse<T> {
  success: true;
  data: T;
  pagination?: PaginationMeta;
}

/**
 * Helper type for error responses
 */
export interface ErrorResponse {
  success: false;
  error: ApiErrorResponse;
}

/**
 * Standard error response structure
 */
export interface ApiErrorResponse {
  message: string;
  code: string;
  details?: unknown;
  timestamp?: string;
  requestId?: string;
}
```

### Express Type Extensions

```typescript
// src/types/express.d.ts

import { ApiKey, User } from "@your-package/shared-library";

declare global {
  namespace Express {
    interface Request {
      /** API key if authenticated via X-API-Key header */
      apiKey?: ApiKey;
      /** User ID extracted from JWT */
      userId?: string;
      /** Full user object loaded from database */
      user?: User;
      /** Request ID for tracing */
      id?: string;
      /** Request start time for performance logging */
      startTime?: number;
    }
  }
}

export {};
```

---

## 3. Route Organization

### Route File Pattern

```typescript
// src/routes/users.routes.ts

import { Router } from "express";
import { authenticateEither } from "../middleware/auth.middleware.js";
import { validate, validateId, validatePagination } from "../middleware/validation.middleware.js";
import { moderateRateLimiter } from "../middleware/rate-limit.middleware.js";
import { UsersController } from "../controllers/users.controller.js";
import { userSchemas } from "../validation/user.schemas.js";

const router: Router = Router();

// Lazy controller instantiation - avoids premature instantiation
const getController = () => new UsersController();

/**
 * Create new user
 * POST /api/users
 */
router.post("/",
  moderateRateLimiter,
  authenticateEither,
  validate({ body: userSchemas.create }),
  (req, res) => getController().create(req, res)
);

/**
 * List all users (paginated)
 * GET /api/users
 */
router.get("/",
  moderateRateLimiter,
  authenticateEither,
  validatePagination,
  (req, res) => getController().list(req, res)
);

/**
 * Get user by ID
 * GET /api/users/:id
 */
router.get("/:id",
  moderateRateLimiter,
  authenticateEither,
  validateId,
  (req, res) => getController().getById(req, res)
);

/**
 * Update user
 * PUT /api/users/:id
 */
router.put("/:id",
  moderateRateLimiter,
  authenticateEither,
  validateId,
  validate({ body: userSchemas.update }),
  (req, res) => getController().update(req, res)
);

/**
 * Delete user
 * DELETE /api/users/:id
 */
router.delete("/:id",
  moderateRateLimiter,
  authenticateEither,
  validateId,
  (req, res) => getController().delete(req, res)
);

export { router as userRoutes };
```

### Central Route Registration

```typescript
// src/routes/index.ts

import { Express } from "express";
import { healthRoutes } from "./health.routes.js";
import { authRoutes } from "./auth.routes.js";
import { userRoutes } from "./users.routes.js";
import { apiKeyRoutes } from "./api-keys.routes.js";

export function setupRoutes(app: Express): void {
  // Health check routes (no auth required)
  app.use("/", healthRoutes);

  // Authentication routes
  app.use("/auth", authRoutes);

  // API routes with authentication
  app.use("/api/users", userRoutes);
  app.use("/api/keys", apiKeyRoutes);
}
```

---

## 4. Authentication Middleware

### Multiple Authentication Strategies

```typescript
// src/middleware/auth.middleware.ts

import { Request, Response, NextFunction } from "express";
import { JWTService } from "../services/jwt.service.js";

/**
 * API Key Authentication
 * Validates X-API-Key header
 */
export async function authenticateApiKey(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const apiKeyHeader = req.headers["x-api-key"] as string | undefined;

  if (!apiKeyHeader || !apiKeyHeader.startsWith("your_prefix_")) {
    sendUnauthorizedError(res, "API key required", "API_KEY_MISSING");
    return;
  }

  const repository = getApiKeyRepository();
  const validationResult = await repository.validateApiKey(apiKeyHeader);

  if (!validationResult.isValid || !validationResult.apiKey) {
    sendUnauthorizedError(res, validationResult.reason || "Invalid API key", "INVALID_API_KEY");
    return;
  }

  req.apiKey = validationResult.apiKey;
  await repository.recordUsage(validationResult.apiKey.id);
  next();
}

/**
 * JWT Token Authentication
 * Validates Authorization header or cookie
 */
export async function requireUser(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  // Check both Authorization header and cookies
  const authHeader = req.headers.authorization;
  let token = JWTService.extractBearerToken(authHeader);

  if (!token && req.cookies?.access_token) {
    token = req.cookies.access_token;
  }

  if (!token) {
    sendUnauthorizedError(res, "Authentication required", "TOKEN_MISSING");
    return;
  }

  try {
    const payload = JWTService.verifyAccessToken(token);

    // Load user from database to verify they still exist
    const userRepo = getUserRepository();
    const user = await userRepo.findById(payload.userId);

    if (!user || !user.is_active) {
      sendUnauthorizedError(res, "User not found or inactive", "USER_INACTIVE");
      return;
    }

    req.user = user;
    req.userId = user.id;
    next();
  } catch (error) {
    sendUnauthorizedError(res, "Invalid token", "INVALID_TOKEN");
  }
}

/**
 * Either/Or Authentication
 * Accepts API key OR JWT token
 */
export async function authenticateEither(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  // Try API key first
  const apiKeyHeader = req.headers["x-api-key"] as string | undefined;
  if (apiKeyHeader && apiKeyHeader.startsWith("your_prefix_")) {
    const repository = getApiKeyRepository();
    const validationResult = await repository.validateApiKey(apiKeyHeader);

    if (validationResult.isValid && validationResult.apiKey) {
      req.apiKey = validationResult.apiKey;
      await repository.recordUsage(validationResult.apiKey.id);
      return next();
    }
  }

  // Fall back to JWT token
  const authHeader = req.headers.authorization;
  let token = JWTService.extractBearerToken(authHeader);

  if (!token && req.cookies?.access_token) {
    token = req.cookies.access_token;
  }

  if (!token) {
    sendUnauthorizedError(res, "Authentication required", "AUTH_REQUIRED");
    return;
  }

  try {
    const payload = JWTService.verifyAccessToken(token);
    const userRepo = getUserRepository();
    const user = await userRepo.findById(payload.userId);

    if (!user || !user.is_active) {
      sendUnauthorizedError(res, "User not found or inactive", "USER_INACTIVE");
      return;
    }

    req.user = user;
    req.userId = user.id;
    next();
  } catch {
    sendUnauthorizedError(res, "Invalid authentication", "INVALID_AUTH");
  }
}

/**
 * Optional API Key
 * Attaches API key if present, but doesn't block request
 */
export async function optionalApiKey(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  const apiKeyHeader = req.headers["x-api-key"] as string | undefined;

  if (apiKeyHeader && apiKeyHeader.startsWith("your_prefix_")) {
    const repository = getApiKeyRepository();
    const validationResult = await repository.validateApiKey(apiKeyHeader);

    if (validationResult.isValid && validationResult.apiKey) {
      req.apiKey = validationResult.apiKey;
      await repository.recordUsage(validationResult.apiKey.id);
    }
  }

  next(); // Always continue, even if no API key
}

// Helper function
function sendUnauthorizedError(res: Response, message: string, code: string): void {
  res.status(401).json({
    error: {
      message,
      code,
      timestamp: new Date().toISOString(),
    },
  });
}
```

---

## 5. Request Validation with Zod

### Validation Middleware

```typescript
// src/middleware/validation.middleware.ts

import { Request, Response, NextFunction } from "express";
import { z, ZodSchema, ZodError } from "zod";
import { createApiError } from "./error.middleware.js";

export interface ValidationSchemas {
  body?: ZodSchema;
  query?: ZodSchema;
  params?: ZodSchema;
}

/**
 * Middleware factory for request validation using Zod schemas
 */
export function validate(schemas: ValidationSchemas) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      // Validate request body
      if (schemas.body) {
        const result = await schemas.body.safeParseAsync(req.body);
        if (!result.success) {
          const errors = formatZodErrors(result.error);
          res.status(400).json({
            success: false,
            error: {
              message: "Invalid request body",
              code: "VALIDATION_ERROR",
              details: errors,
              timestamp: new Date().toISOString(),
            },
          });
          return;
        }
        req.body = result.data; // Use parsed/transformed data
      }

      // Validate query parameters
      if (schemas.query) {
        const result = await schemas.query.safeParseAsync(req.query);
        if (!result.success) {
          const errors = formatZodErrors(result.error);
          res.status(400).json({
            success: false,
            error: {
              message: "Invalid query parameters",
              code: "VALIDATION_ERROR",
              details: errors,
              timestamp: new Date().toISOString(),
            },
          });
          return;
        }
        // Assign validated data back to query
        Object.assign(req.query, result.data);
      }

      // Validate URL parameters
      if (schemas.params) {
        const result = await schemas.params.safeParseAsync(req.params);
        if (!result.success) {
          const errors = formatZodErrors(result.error);
          res.status(400).json({
            success: false,
            error: {
              message: "Invalid URL parameters",
              code: "VALIDATION_ERROR",
              details: errors,
              timestamp: new Date().toISOString(),
            },
          });
          return;
        }
        Object.assign(req.params, result.data);
      }

      next();
    } catch (error) {
      res.status(500).json({
        success: false,
        error: {
          message: "Validation failed",
          code: "VALIDATION_ERROR",
          timestamp: new Date().toISOString(),
        },
      });
    }
  };
}

function formatZodErrors(error: ZodError): Array<{ field: string; message: string; code: string }> {
  return error.errors.map((err) => ({
    field: err.path.join("."),
    message: err.message,
    code: err.code,
  }));
}
```

### Common Validation Schemas

```typescript
// src/middleware/validation.middleware.ts (continued)

const SORT_DIRECTIONS = ["asc", "desc", "ASC", "DESC"] as const;

export const commonSchemas = {
  // UUID validation
  uuid: z.string().uuid("Invalid UUID format"),

  // Pagination
  pagination: z.object({
    limit: z.coerce.number().int().min(1).max(100).default(20).optional(),
    offset: z.coerce.number().int().min(0).default(0).optional(),
    page: z.coerce.number().int().min(1).optional(),
  }).passthrough(),

  // Sorting
  sorting: z.object({
    sortBy: z.string().optional(),
    sortOrder: z.enum(SORT_DIRECTIONS).optional(),
    sortDirection: z.enum(SORT_DIRECTIONS).optional(),
  }).passthrough(),

  // Date range
  dateRange: z.object({
    startDate: z.coerce.date().optional(),
    endDate: z.coerce.date().optional(),
  }),

  // Search
  search: z.object({
    q: z.string().min(1).max(255).optional(),
  }),
};

// Pre-built middleware
export const validateId = validate({
  params: z.object({
    id: commonSchemas.uuid,
  }),
});

export const validatePagination = validate({
  query: commonSchemas.pagination.merge(commonSchemas.sorting),
});

export const validateSearch = validate({
  query: commonSchemas.search.merge(commonSchemas.pagination),
});
```

### API-Specific Schemas

```typescript
// src/validation/user.schemas.ts

import { z } from "zod";

export const userSchemas = {
  create: z.object({
    email: z.string().email("Invalid email format"),
    name: z.string().min(1).max(100),
    role: z.enum(["admin", "user", "viewer"]).optional().default("user"),
  }),

  update: z.object({
    email: z.string().email("Invalid email format").optional(),
    name: z.string().min(1).max(100).optional(),
    role: z.enum(["admin", "user", "viewer"]).optional(),
    is_active: z.boolean().optional(),
  }),
};

// Type inference from schemas
export type CreateUserRequest = z.infer<typeof userSchemas.create>;
export type UpdateUserRequest = z.infer<typeof userSchemas.update>;
```

---

## 6. Error Handling

### Custom Error Classes (Shared Library)

```typescript
// shared-library/errors/base-error.ts

export abstract class BaseError extends Error {
  public code: string;
  public readonly statusCode: number;
  public readonly isOperational: boolean;
  public readonly context: Record<string, unknown> | undefined;
  public readonly errorCause: Error | undefined;

  constructor(
    message: string,
    code: string,
    statusCode: number = 500,
    isOperational: boolean = true,
    context?: Record<string, unknown>,
    cause?: Error,
  ) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.context = context;
    this.errorCause = cause;

    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }

  toJSON(): Record<string, unknown> {
    return {
      name: this.name,
      message: this.message,
      code: this.code,
      statusCode: this.statusCode,
      isOperational: this.isOperational,
      context: this.context,
      timestamp: new Date().toISOString(),
      ...(this.errorCause && { cause: this.errorCause.message }),
    };
  }

  getUserMessage(): string {
    return this.message;
  }
}
```

### Specialized Error Types

```typescript
// shared-library/errors/application-errors.ts

import { BaseError } from "./base-error.js";

export class NotFoundError extends BaseError {
  public readonly resource: string;
  public readonly resourceId: string | undefined;

  constructor(resource: string, resourceId?: string, message?: string) {
    const defaultMessage = resourceId
      ? `${resource} with ID '${resourceId}' not found`
      : `${resource} not found`;

    super(message || defaultMessage, "NOT_FOUND", 404, true, {
      resource,
      resourceId,
    });
    this.resource = resource;
    this.resourceId = resourceId;
  }
}

export class ValidationError extends BaseError {
  public readonly validationErrors: string[];

  constructor(message: string, validationErrors: string[] = [], context?: Record<string, unknown>) {
    super(message, "VALIDATION_ERROR", 400, true, context);
    this.validationErrors = validationErrors;
  }
}

export class AuthenticationError extends BaseError {
  constructor(message: string = "Authentication required", context?: Record<string, unknown>) {
    super(message, "AUTHENTICATION_ERROR", 401, true, context);
  }
}

export class AuthorizationError extends BaseError {
  constructor(message: string = "Insufficient permissions", context?: Record<string, unknown>) {
    super(message, "AUTHORIZATION_ERROR", 403, true, context);
  }
}

export class DatabaseError extends BaseError {
  constructor(message: string, context?: Record<string, unknown>, cause?: Error) {
    super(message, "DATABASE_ERROR", 500, true, context, cause);
  }
}

export class RateLimitError extends BaseError {
  public readonly retryAfter: number | undefined;

  constructor(message: string = "Rate limit exceeded", retryAfter?: number, context?: Record<string, unknown>) {
    super(message, "RATE_LIMIT_ERROR", 429, true, { retryAfter, ...context });
    this.retryAfter = retryAfter;
  }
}

export class ConflictError extends BaseError {
  constructor(message: string, context?: Record<string, unknown>) {
    super(message, "CONFLICT_ERROR", 409, true, context);
  }
}
```

### Error Middleware

```typescript
// src/middleware/error.middleware.ts

import { Request, Response, NextFunction } from "express";
import { config } from "../config/index.js";
import { logger } from "../utils/logger.js";

export interface ApiError extends Error {
  status?: number;
  code?: string;
  details?: unknown;
}

export function createApiError(
  message: string,
  status: number = 500,
  code?: string,
  details?: unknown
): ApiError {
  const error: ApiError = new Error(message);
  error.status = status;
  if (code !== undefined) {
    error.code = code;
  }
  error.details = details;
  return error;
}

export function errorMiddleware(
  error: ApiError,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const errorContext = {
    method: req.method,
    path: req.path,
    url: req.url,
    statusCode: error.status || 500,
    errorCode: error.code || "INTERNAL_ERROR",
    timestamp: new Date().toISOString(),
    requestId: req.id || `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  };

  // Log server errors with full details
  if ((error.status || 500) >= 500) {
    logger.error('Server error occurred', error, {
      ...errorContext,
      stack: error.stack,
    });
  } else {
    logger.warn(`Request error: ${req.method} ${req.path}`, errorContext);
  }

  if (res.headersSent) {
    logger.warn('Cannot send error response - headers already sent', errorContext);
    return;
  }

  const statusCode = error.status || 500;
  const errorResponse: Record<string, unknown> = {
    success: false,
    error: {
      message: error.message || "An unexpected error occurred",
      code: error.code || "INTERNAL_ERROR",
      timestamp: errorContext.timestamp,
      requestId: errorContext.requestId,
    },
  };

  // Include stack trace in development
  if (config.server.isDevelopment && error.stack) {
    (errorResponse.error as Record<string, unknown>).stack = error.stack.split("\n");
  }

  // Include validation details if present
  if (error.details) {
    (errorResponse.error as Record<string, unknown>).details = error.details;
  }

  res.status(statusCode).json(errorResponse);
}

// Prisma error handler helper
export function handleDatabaseError(error: Error): ApiError {
  const prismaError = error as { code?: string; meta?: { target?: string[] } };

  // Prisma unique constraint violation
  if (prismaError.code === "P2002") {
    const field = prismaError.meta?.target?.[0] || "field";
    return createApiError(`A record with this ${field} already exists`, 409, "DUPLICATE_ERROR", { field });
  }

  // Prisma record not found
  if (prismaError.code === "P2025") {
    return createApiError("Record not found", 404, "NOT_FOUND");
  }

  // Prisma foreign key constraint violation
  if (prismaError.code === "P2003") {
    return createApiError("Referenced record not found", 400, "REFERENCE_ERROR");
  }

  return createApiError("Database operation failed", 500, "DATABASE_ERROR");
}
```

---

## 7. Pagination

### Base Controller Pagination Helpers

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

### Usage in Controllers

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

---

## 8. Response Formatting

### Response Utilities

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

## 9. Rate Limiting

### Multiple Rate Limiters

```typescript
// src/middleware/rate-limit.middleware.ts

import rateLimit from "express-rate-limit";
import { Request, Response } from "express";
import { config } from "../config/index.js";
import { logger } from "../utils/logger.js";

interface RateLimiterOptions {
  windowMs: number;
  max: number;
  message?: string;
  keyGenerator?: (req: Request) => string;
}

function createRateLimiter(options: RateLimiterOptions) {
  return rateLimit({
    windowMs: options.windowMs,
    max: options.max,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: options.keyGenerator || getKeyGenerator(),
    handler: (req: Request, res: Response) => {
      const key = options.keyGenerator ? options.keyGenerator(req) : getKeyGenerator()(req);
      logger.warn(`Rate limit exceeded for ${key}`, {
        ip: req.ip,
        path: req.path,
        apiKey: req.apiKey?.name,
      });

      res.status(429).json({
        error: {
          message: options.message || "Too many requests, please try again later",
          code: "RATE_LIMIT_EXCEEDED",
          retryAfter: res.get("Retry-After"),
        },
      });
    },
  });
}

function getKeyGenerator() {
  return (req: Request): string => {
    // Use API key ID if authenticated, otherwise use IP
    if (req.apiKey) {
      return `api-key:${req.apiKey.id}`;
    }
    return `ip:${req.ip || req.socket.remoteAddress || "unknown"}`;
  };
}

/**
 * Strict rate limiter for sensitive endpoints (5 req/15 min)
 * Use for: login, password reset, account creation
 */
export const strictRateLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  message: "Too many attempts, please try again later",
});

/**
 * Moderate rate limiter for general API endpoints (100 req/min)
 * Use for: most CRUD operations
 */
export const moderateRateLimiter = createRateLimiter({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
});

/**
 * Lenient rate limiter for read-only endpoints (200 req/min)
 * Use for: list endpoints, search, health checks
 */
export const lenientRateLimiter = createRateLimiter({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 200,
});

/**
 * Dynamic rate limiter - higher limits for authenticated users
 */
export function createDynamicRateLimiter() {
  return rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: (req: Request): number => {
      if (req.apiKey || req.user) {
        return 200; // Authenticated users get higher limits
      }
      return 50; // Unauthenticated users get lower limits
    },
    keyGenerator: getKeyGenerator(),
    standardHeaders: true,
    legacyHeaders: false,
  });
}
```

---

## 10. Logging Middleware

### Request/Response Logging

```typescript
// src/middleware/logging.middleware.ts

import { Request, Response, NextFunction } from "express";
import { randomUUID } from "crypto";
import { logger } from "../utils/logger.js";
import { config } from "../config/index.js";

export function loggingMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  // Generate unique request ID
  req.id = randomUUID();
  req.startTime = Date.now();

  const requestLog: Record<string, unknown> = {
    id: req.id,
    method: req.method,
    url: req.url,
    path: req.path,
    query: req.query,
    ip: req.ip || req.socket.remoteAddress,
    userAgent: req.get("user-agent"),
    apiKey: req.apiKey?.name,
  };

  // Don't log sensitive data in production
  if (config.server.isDevelopment) {
    requestLog.headers = sanitizeHeaders(req.headers);
    if (req.body && Object.keys(req.body).length > 0) {
      requestLog.body = sanitizeBody(req.body);
    }
  }

  logger.info(`Request started: ${req.method} ${req.path}`, requestLog);

  // Capture response
  const originalSend = res.send;
  res.send = function (data): Response {
    res.send = originalSend;

    const duration = Date.now() - (req.startTime || 0);
    const responseLog = {
      id: req.id,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      contentLength: res.get("content-length"),
    };

    if (res.statusCode >= 400) {
      logger.warn(`Request failed: ${req.method} ${req.path}`, responseLog);
    } else {
      logger.info(`Request completed: ${req.method} ${req.path}`, responseLog);
    }

    return originalSend.call(this, data);
  };

  next();
}

// Redact sensitive headers
function sanitizeHeaders(headers: Record<string, unknown>): Record<string, unknown> {
  const sanitized = { ...headers };
  const sensitiveHeaders = ["authorization", "x-api-key", "cookie", "x-auth-token"];

  for (const header of sensitiveHeaders) {
    if (sanitized[header]) {
      sanitized[header] = "[REDACTED]";
    }
  }

  return sanitized;
}

// Redact sensitive body fields
function sanitizeBody(body: Record<string, unknown>): Record<string, unknown> {
  const sanitized = { ...body };
  const sensitiveFields = ["password", "token", "secret", "apiKey", "privateKey"];

  for (const field of sensitiveFields) {
    if (field in sanitized) {
      sanitized[field] = "[REDACTED]";
    }
  }

  // Recursively sanitize nested objects
  for (const key in sanitized) {
    if (typeof sanitized[key] === "object" && sanitized[key] !== null) {
      sanitized[key] = sanitizeBody(sanitized[key] as Record<string, unknown>);
    }
  }

  return sanitized;
}
```

---

## 11. Base Controller Pattern

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

---

## 12. Complete Example

### App Initialization

```typescript
// src/app.ts

import express, { Express, Request, Response, NextFunction } from "express";
import helmet from "helmet";
import cors from "cors";
import compression from "compression";
import cookieParser from "cookie-parser";
import { config } from "./config/index.js";
import { setupRoutes } from "./routes/index.js";
import { errorMiddleware } from "./middleware/error.middleware.js";
import { loggingMiddleware } from "./middleware/logging.middleware.js";
import { createRateLimiter } from "./middleware/rate-limit.middleware.js";

export function createApp(): Express {
  const app = express();

  // 1. Security middleware
  app.use(helmet());

  // 2. CORS
  app.use(cors({
    origin: config.cors.origin,
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-API-Key"],
  }));

  // 3. Compression
  app.use(compression());

  // 4. Cookie parsing
  app.use(cookieParser());

  // 5. Body parsing
  app.use(express.json({ limit: "10mb" }));
  app.use(express.urlencoded({ extended: true, limit: "10mb" }));

  // 6. Request logging
  app.use(loggingMiddleware);

  // 7. Global rate limiting
  app.use(createRateLimiter({
    windowMs: config.rateLimit.windowMs,
    max: config.rateLimit.max,
  }));

  // 8. Health check (no auth)
  app.get("/health", (_req, res) => {
    res.json({
      success: true,
      data: {
        status: "healthy",
        timestamp: new Date().toISOString(),
        environment: config.server.nodeEnv,
        uptime: process.uptime(),
      },
    });
  });

  // 9. Setup routes
  setupRoutes(app);

  // 10. Global error handler (MUST be last)
  app.use(errorMiddleware);

  // 11. 404 handler
  app.use((req: Request, res: Response) => {
    res.status(404).json({
      success: false,
      error: {
        message: "Endpoint not found",
        code: "NOT_FOUND",
        path: req.path,
        method: req.method,
        timestamp: new Date().toISOString(),
      },
    });
  });

  return app;
}
```

### Complete Controller Example

```typescript
// src/controllers/users.controller.ts

import { Request, Response } from "express";
import { BaseController } from "./base.controller.js";
import { NotFoundError } from "@your-package/shared-library";

export class UsersController extends BaseController {
  /**
   * Create new user
   * POST /api/users
   */
  create = this.handleAsync(async (req: Request, res: Response): Promise<void> => {
    const userRepo = this.db.getUserRepository();
    const user = await userRepo.create(req.body);

    this.logger.info("User created", { userId: user.id });
    this.sendCreated(res, user);
  });

  /**
   * List users (paginated)
   * GET /api/users
   */
  list = this.handleAsync(async (req: Request, res: Response): Promise<void> => {
    const { page, limit, offset } = this.getPagination(req);

    const userRepo = this.db.getUserRepository();
    const result = await userRepo.list(offset, limit);

    this.logger.info("Users retrieved", {
      count: result.items.length,
      total: result.total,
      page,
    });

    this.sendPaginatedResponse(res, result.items, result.total, page, limit);
  });

  /**
   * Get user by ID
   * GET /api/users/:id
   */
  getById = this.handleAsync(async (req: Request, res: Response): Promise<void> => {
    const userRepo = this.db.getUserRepository();
    const user = await userRepo.findById(req.params.id);

    if (!user) {
      throw new NotFoundError("User", req.params.id);
    }

    this.sendSuccess(res, user);
  });

  /**
   * Update user
   * PUT /api/users/:id
   */
  update = this.handleAsync(async (req: Request, res: Response): Promise<void> => {
    const userRepo = this.db.getUserRepository();
    const user = await userRepo.update(req.params.id, req.body);

    if (!user) {
      throw new NotFoundError("User", req.params.id);
    }

    this.logger.info("User updated", { userId: user.id });
    this.sendSuccess(res, user);
  });

  /**
   * Delete user
   * DELETE /api/users/:id
   */
  delete = this.handleAsync(async (req: Request, res: Response): Promise<void> => {
    const userRepo = this.db.getUserRepository();
    const deleted = await userRepo.delete(req.params.id);

    if (!deleted) {
      throw new NotFoundError("User", req.params.id);
    }

    this.logger.info("User deleted", { userId: req.params.id });
    this.sendNoContent(res);
  });
}
```

---

## Summary: Key Patterns

| Pattern | Purpose | Location |
|---------|---------|----------|
| **Lazy Controller Instantiation** | Avoid premature object creation | Routes |
| **ValidationSchemas Interface** | Type-safe request validation | Middleware |
| **Custom Error Classes** | Semantic error handling with HTTP codes | Shared library |
| **PaginatedResponse<T>** | Consistent paginated API responses | Shared types |
| **handleAsync Wrapper** | Automatic async error forwarding | Base controller |
| **Multiple Auth Strategies** | Flexible authentication (API key, JWT, either) | Auth middleware |
| **Tiered Rate Limiters** | Different limits for different endpoints | Rate limit middleware |
| **Request Sanitization** | Secure logging without sensitive data | Logging middleware |
| **Central Route Registration** | Clean route organization | Routes index |

---

## Benefits of This Architecture

1. **Type Safety**: Full TypeScript with strict mode, Zod validation
2. **Consistency**: Standardized response formats across all endpoints
3. **Security**: Built-in rate limiting, auth strategies, request sanitization
4. **Observability**: Comprehensive logging with request tracing
5. **Maintainability**: Clean separation of concerns, reusable patterns
6. **Scalability**: Shared library enables consistent patterns across services
7. **Developer Experience**: Pre-built middleware, base controller helpers
