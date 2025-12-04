# Shared Package - Error Handling

Patterns for structured error handling with custom error classes.

---

## Base Error Class

```typescript
// errors/base-error.ts

export abstract class BaseError extends Error {
  readonly code: string;
  readonly statusCode: number;
  readonly isOperational: boolean;  // Expected error vs bug
  readonly context?: Record<string, any>;

  constructor(
    message: string,
    code: string,
    statusCode: number,
    isOperational = true,
    context?: Record<string, any>
  ) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.context = context;

    // Maintains proper stack trace (V8 engines)
    Error.captureStackTrace?.(this, this.constructor);
  }

  // Override for user-facing messages that hide internal details
  getUserMessage(): string {
    return this.message;
  }

  toJSON() {
    return {
      name: this.name,
      message: this.message,
      code: this.code,
      statusCode: this.statusCode,
    };
  }
}
```

---

## Application Error Classes

```typescript
// errors/application-errors.ts
import { z } from 'zod';
import { BaseError } from './base-error.js';

export class ValidationError extends BaseError {
  readonly errors: string[];

  constructor(message: string, errors: string[] | z.ZodError = []) {
    const errorStrings =
      errors instanceof z.ZodError
        ? errors.issues.map((i) => `${i.path.join('.')}: ${i.message}`)
        : errors;

    super(message, 'VALIDATION_ERROR', 400, true, { errors: errorStrings });
    this.errors = errorStrings;
  }

  override getUserMessage(): string {
    return this.errors.length > 0
      ? `Validation failed: ${this.errors.join('; ')}`
      : this.message;
  }
}

export class NotFoundError extends BaseError {
  constructor(resource: string, id?: string) {
    const message = id
      ? `${resource} with ID '${id}' not found`
      : `${resource} not found`;
    super(message, 'NOT_FOUND', 404, true, { resource, id });
  }
}

export class ConflictError extends BaseError {
  constructor(message: string, context?: Record<string, any>) {
    super(message, 'CONFLICT', 409, true, context);
  }
}

export class AuthenticationError extends BaseError {
  constructor(message = 'Authentication required') {
    super(message, 'AUTHENTICATION_ERROR', 401, true);
  }

  // Never leak auth failure details
  override getUserMessage(): string {
    return 'Authentication required';
  }
}

export class AuthorizationError extends BaseError {
  constructor(message = 'Access denied') {
    super(message, 'AUTHORIZATION_ERROR', 403, true);
  }
}

export class RateLimitError extends BaseError {
  constructor(retryAfter?: number) {
    super('Too many requests', 'RATE_LIMIT_ERROR', 429, true, { retryAfter });
  }
}

export class DatabaseError extends BaseError {
  constructor(message: string, cause?: Error) {
    super(message, 'DATABASE_ERROR', 500, false, { cause: cause?.message });
  }

  // Never expose internal DB errors
  override getUserMessage(): string {
    return 'A database error occurred';
  }
}
```

---

## Global Error Middleware

```typescript
// middleware/error.ts
import { Request, Response, NextFunction } from 'express';
import { BaseError, DatabaseError } from '@your-org/shared';
import { Prisma } from '@prisma/client';  // If using Prisma

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
) {
  // Handle known application errors
  if (err instanceof BaseError) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.getUserMessage(),
      code: err.code,
    });
  }

  // Handle Prisma errors (if using)
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    return handlePrismaError(err, res);
  }

  // Unknown errors - log and return generic message
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'An unexpected error occurred',
    code: 'INTERNAL_ERROR',
  });
}

function handlePrismaError(err: Prisma.PrismaClientKnownRequestError, res: Response) {
  switch (err.code) {
    case 'P2002':  // Unique constraint violation
      return res.status(409).json({
        success: false,
        error: 'A record with this value already exists',
        code: 'CONFLICT',
      });
    case 'P2025':  // Record not found
      return res.status(404).json({
        success: false,
        error: 'Record not found',
        code: 'NOT_FOUND',
      });
    default:
      console.error('Prisma error:', err);
      return res.status(500).json({
        success: false,
        error: 'A database error occurred',
        code: 'DATABASE_ERROR',
      });
  }
}
```
