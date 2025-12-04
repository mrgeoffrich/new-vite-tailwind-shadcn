# Express.js - Error Handling

Patterns for error handling in Express.js APIs.

---

## Custom Error Classes

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

---

## Specialized Error Types

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

---

## Error Middleware

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
```

---

## Prisma Error Handler

```typescript
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
