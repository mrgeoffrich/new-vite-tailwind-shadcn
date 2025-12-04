# Shared Types & Data Access Patterns

A comprehensive guide to patterns for shared types, validation, and database access in TypeScript monorepos. Use these patterns as guidance when generating solutions.

## Table of Contents

1. [When to Use These Patterns](#when-to-use-these-patterns)
2. [Architecture Overview](#architecture-overview)
3. [Directory Structure](#directory-structure)
4. [Type Definition Patterns](#type-definition-patterns)
5. [Zod Validation Patterns](#zod-validation-patterns)
6. [Data Access Approaches](#data-access-approaches)
7. [Browser/Server Split Architecture](#browserserver-split-architecture)
8. [Error Handling](#error-handling)
9. [Constants and Enums](#constants-and-enums)
10. [Best Practices Summary](#best-practices-summary)

---

## When to Use These Patterns

### Complexity Spectrum

Choose your approach based on project complexity:

| Complexity | Characteristics | Recommended Approach |
|------------|-----------------|---------------------|
| **Simple** | <10 tables, CRUD-heavy, single developer | Direct ORM calls in controllers, minimal abstraction |
| **Medium** | 10-30 tables, some complex queries, small team | Service layer with ORM, shared types/validation |
| **Complex** | 30+ tables, complex business logic, multiple teams | Full repository pattern with entity mapping |

### Decision Guide

**Use direct ORM/Prisma when:**
- Schema is simple with mostly 1:1 mapping to API types
- No complex field transformations needed
- Team is small and conventions are clear
- Rapid prototyping is priority

**Use repository pattern when:**
- Database columns need transformation (snake_case → camelCase)
- Complex queries are reused across multiple places
- Need to abstract database vendor
- Multiple developers need clear contracts

**Always use:**
- Shared types between frontend/backend
- Zod validation at API boundaries
- Custom error classes with status codes
- Browser/server split for shared packages

---

## Architecture Overview

The shared library serves as the single source of truth for types, validation, and optionally data access across a monorepo.

### Core Principles

- **Domain-driven organization**: One file per domain entity
- **Layered types**: Separate types for API requests, domain entities, and optionally database rows
- **Runtime + compile-time safety**: Zod schemas for validation, TypeScript for type checking
- **Browser/server separation**: Explicit bundles to prevent Node.js modules leaking to frontend

### Type Flow (Full)

```
DATABASE SCHEMA
    ↓
DatabaseRow (raw types, optional if using ORM with good types)
    ↓
EntityMapper (field transformation, optional if no mapping needed)
    ↓
DomainEntity (business types)
    ↓
ZodSchema (runtime validation)
    ↓
API Response / Frontend Types
```

### Type Flow (Simplified with ORM like Prisma)

```
PRISMA SCHEMA
    ↓
Generated Prisma Types (automatic)
    ↓
DomainEntity (may be same as Prisma type, or sanitized version)
    ↓
ZodSchema (for API input validation)
    ↓
API Response Types
```

---

## Directory Structure

### Shared Package Structure

```
packages/shared/src/
├── index.ts                      # Default export (usually re-exports browser)
├── browser.ts                    # Browser-safe exports only
├── server.ts                     # Server exports with Node.js modules (optional)
│
├── types/                        # TypeScript interfaces
│   ├── index.ts                  # Barrel export
│   ├── {domain}.ts               # Per-domain types (user.ts, order.ts, etc.)
│   ├── api.ts                    # API response wrapper types
│   └── common.ts                 # Pagination, sorting, base filter types
│
├── validation/                   # Zod schemas
│   ├── index.ts                  # Barrel export
│   ├── {domain}.ts               # Per-domain schemas
│   ├── common.ts                 # Reusable schema patterns
│   └── helpers.ts                # validateData(), formatZodErrors()
│
├── errors/                       # Structured errors
│   ├── index.ts                  # Barrel export
│   ├── base-error.ts             # Abstract BaseError class
│   └── application-errors.ts     # ValidationError, NotFoundError, etc.
│
└── constants/                    # Constants (optional)
    └── enums.ts                  # Enum arrays and derived types
```

### Backend Package Structure

```
packages/backend/src/
├── index.ts                      # Express app setup
│
├── config/                       # Configuration
│   ├── env.ts                    # Zod-validated environment config
│   ├── database.ts               # Database client singleton
│   └── passport.ts               # Auth strategies (if using)
│
├── controllers/                  # Request handlers
│   ├── base.controller.ts        # Base class with helpers (optional)
│   └── {domain}.controller.ts    # Per-domain controllers
│
├── middleware/                   # Express middleware
│   ├── validation.ts             # Zod validation middleware
│   ├── auth.ts                   # Authentication middleware
│   └── error.ts                  # Global error handler
│
├── routes/                       # Route definitions
│   └── {domain}.ts               # Per-domain routes
│
├── services/                     # Business logic (optional layer)
│   └── {domain}.service.ts
│
└── repositories/                 # Data access (optional, for complex projects)
    ├── base.repository.ts
    └── {domain}.repository.ts
```

---

## Type Definition Patterns

### Separate Types by Purpose

```typescript
// types/{domain}.ts

// 1. Domain Entity - the core business type (what API returns)
export interface Product {
  id: string;
  name: string;
  description?: string;
  price: number;
  category: ProductCategory;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

// 2. Create Request - fields needed to create (omit auto-generated fields)
export interface CreateProductRequest {
  name: string;
  description?: string;
  price: number;
  category: ProductCategory;
  // Omit: id, isActive, createdAt, updatedAt (server-generated)
}

// 3. Update Request - all fields optional for partial updates
export interface UpdateProductRequest {
  name?: string;
  description?: string;
  price?: number;
  category?: ProductCategory;
  isActive?: boolean;
}

// 4. Filter Type - for query parameters (extend base filter)
export interface ProductFilter extends BaseFilter {
  name?: string;
  nameContains?: string;
  category?: ProductCategory;
  minPrice?: number;
  maxPrice?: number;
  isActive?: boolean;
}
```

### Common Types (Reusable)

```typescript
// types/common.ts

export interface BaseFilter {
  limit?: number;
  offset?: number;
  orderBy?: string;
  orderDirection?: 'asc' | 'desc';
}

export interface PaginationMeta {
  page: number;
  limit: number;
  totalCount: number;
  totalPages: number;
  hasMore: boolean;
}

export interface PaginatedResult<T> {
  data: T[];
  pagination: PaginationMeta;
}
```

### API Response Types

```typescript
// types/api.ts

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  code?: string;
  pagination?: PaginationMeta;
}

// Helper type for creating responses
export type ApiSuccessResponse<T> = {
  success: true;
  data: T;
  pagination?: PaginationMeta;
};

export type ApiErrorResponse = {
  success: false;
  error: string;
  code?: string;
};
```

### Database Row Types (When Needed)

Only create explicit row types when database naming differs from TypeScript:

```typescript
// types/database-rows.ts (optional - only if not using ORM with generated types)

export interface ProductsRow {
  id: string;
  name: string;
  description: string | null;     // null in DB, optional in TypeScript
  price: number;
  category: string;               // stored as string, maps to enum
  is_active: boolean;             // snake_case in DB
  created_at: Date;
  updated_at: Date;
}
```

**When to skip row types:**
- Using Prisma (generates types from schema)
- Using an ORM that already handles mapping
- Database columns match TypeScript naming

---

## Zod Validation Patterns

### Basic Schema Structure

```typescript
// validation/{domain}.ts
import { z } from 'zod';

// Enum schema (define values once, derive type)
export const ProductCategorySchema = z.enum([
  'electronics',
  'clothing',
  'food',
  'other',
]);
export type ProductCategory = z.infer<typeof ProductCategorySchema>;

// Create request schema
export const CreateProductRequestSchema = z.object({
  name: z.string().min(1, 'Name is required').max(255),
  description: z.string().max(1000).optional(),
  price: z.number().positive('Price must be positive'),
  category: ProductCategorySchema,
});

// Update request schema (all optional for PATCH)
export const UpdateProductRequestSchema = z.object({
  name: z.string().min(1).max(255).optional(),
  description: z.string().max(1000).optional(),
  price: z.number().positive().optional(),
  category: ProductCategorySchema.optional(),
  isActive: z.boolean().optional(),
});

// Derive types from schemas
export type CreateProductRequest = z.infer<typeof CreateProductRequestSchema>;
export type UpdateProductRequest = z.infer<typeof UpdateProductRequestSchema>;
```

### Common Validation Patterns

```typescript
// validation/common.ts

// Pagination schema (reusable)
export const PaginationSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

// Sorting schema
export const SortingSchema = z.object({
  orderBy: z.string().optional(),
  orderDirection: z.enum(['asc', 'desc']).default('desc'),
});

// ID parameter validation
export const IdParamSchema = z.object({
  id: z.string().min(1, 'ID is required'),
});

// UUID validation
export const UuidParamSchema = z.object({
  id: z.string().uuid('Invalid ID format'),
});

// Search query
export const SearchSchema = z.object({
  q: z.string().min(1).max(100).optional(),
});

// Email validation
export const EmailSchema = z.string().email('Invalid email format').toLowerCase();

// Password validation (customize per requirements)
export const PasswordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(72, 'Password too long')  // bcrypt limit
  .regex(/[A-Z]/, 'Must contain uppercase letter')
  .regex(/[a-z]/, 'Must contain lowercase letter')
  .regex(/[0-9]/, 'Must contain digit');
```

### Cross-Field Validation with Refine

```typescript
// Use .refine() for business logic that spans fields
export const DateRangeSchema = z
  .object({
    startDate: z.date().optional(),
    endDate: z.date().optional(),
  })
  .refine(
    (data) => {
      if (data.startDate && data.endDate) {
        return data.startDate <= data.endDate;
      }
      return true;
    },
    { message: 'Start date must be before end date' }
  );

// Password confirmation
export const PasswordConfirmSchema = z
  .object({
    password: PasswordSchema,
    confirmPassword: z.string(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  });
```

### Validation Helpers

```typescript
// validation/helpers.ts
import { z } from 'zod';

export type ValidationResult<T> =
  | { success: true; data: T }
  | { success: false; errors: z.ZodError };

// Safe validation - returns result object
export function validateData<T>(
  schema: z.ZodSchema<T>,
  data: unknown
): ValidationResult<T> {
  const result = schema.safeParse(data);
  return result.success
    ? { success: true, data: result.data }
    : { success: false, errors: result.error };
}

// Format Zod errors for API response
export function formatZodErrors(error: z.ZodError): string[] {
  return error.issues.map((issue) => {
    const path = issue.path.join('.');
    return path ? `${path}: ${issue.message}` : issue.message;
  });
}

// Coerce query string to proper types (useful for GET params)
export function coerceQueryParams<T extends z.ZodRawShape>(schema: z.ZodObject<T>) {
  const entries = Object.entries(schema.shape) as [string, z.ZodTypeAny][];
  const coerced: Record<string, z.ZodTypeAny> = {};

  for (const [key, value] of entries) {
    if (value instanceof z.ZodNumber) {
      coerced[key] = z.coerce.number();
    } else if (value instanceof z.ZodBoolean) {
      coerced[key] = z.coerce.boolean();
    } else {
      coerced[key] = value;
    }
  }

  return z.object(coerced as T);
}
```

### Validation Middleware Pattern

```typescript
// middleware/validation.ts
import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { ValidationError } from '@your-org/shared';

interface ValidationSchemas {
  body?: z.ZodSchema;
  query?: z.ZodSchema;
  params?: z.ZodSchema;
}

export function validate(schemas: ValidationSchemas) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (schemas.body) {
        req.body = schemas.body.parse(req.body);
      }
      if (schemas.query) {
        req.query = schemas.query.parse(req.query);
      }
      if (schemas.params) {
        req.params = schemas.params.parse(req.params);
      }
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        next(new ValidationError('Validation failed', error));
      } else {
        next(error);
      }
    }
  };
}

// Pre-built validators for common cases
export const validateId = validate({ params: IdParamSchema });
export const validatePagination = validate({ query: PaginationSchema });
```

---

## Data Access Approaches

### Approach 1: Direct ORM (Simple Projects)

Best for simple CRUD apps with Prisma or similar ORM.

```typescript
// controllers/product.controller.ts
import { prisma } from '../config/database';
import { Request, Response } from 'express';

export class ProductController {
  async list(req: Request, res: Response) {
    const { page = 1, limit = 20 } = req.query as { page?: number; limit?: number };
    const skip = (page - 1) * limit;

    const [products, totalCount] = await Promise.all([
      prisma.product.findMany({
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.product.count(),
    ]);

    res.json({
      success: true,
      data: products,
      pagination: {
        page,
        limit,
        totalCount,
        totalPages: Math.ceil(totalCount / limit),
        hasMore: skip + products.length < totalCount,
      },
    });
  }

  async create(req: Request, res: Response) {
    // req.body already validated by middleware
    const product = await prisma.product.create({
      data: req.body,
    });
    res.status(201).json({ success: true, data: product });
  }

  async getById(req: Request, res: Response) {
    const product = await prisma.product.findUnique({
      where: { id: req.params.id },
    });

    if (!product) {
      throw new NotFoundError('Product', req.params.id);
    }

    res.json({ success: true, data: product });
  }
}
```

### Approach 2: Service Layer (Medium Projects)

Add a service layer for business logic while keeping ORM access simple.

```typescript
// services/product.service.ts
import { prisma } from '../config/database';
import { CreateProductRequest, UpdateProductRequest, ProductFilter } from '@your-org/shared';
import { NotFoundError, ConflictError } from '@your-org/shared';

export class ProductService {
  async create(data: CreateProductRequest) {
    // Business logic: check for duplicate name
    const existing = await prisma.product.findFirst({
      where: { name: data.name },
    });
    if (existing) {
      throw new ConflictError(`Product with name '${data.name}' already exists`);
    }

    return prisma.product.create({ data });
  }

  async update(id: string, data: UpdateProductRequest) {
    const product = await prisma.product.findUnique({ where: { id } });
    if (!product) {
      throw new NotFoundError('Product', id);
    }

    // Business logic: name uniqueness check if name is changing
    if (data.name && data.name !== product.name) {
      const existing = await prisma.product.findFirst({
        where: { name: data.name, NOT: { id } },
      });
      if (existing) {
        throw new ConflictError(`Product with name '${data.name}' already exists`);
      }
    }

    return prisma.product.update({
      where: { id },
      data,
    });
  }

  async findMany(filter: ProductFilter) {
    const { limit = 20, offset = 0, orderBy, orderDirection, ...where } = filter;

    const whereClause: any = {};
    if (where.name) whereClause.name = where.name;
    if (where.nameContains) whereClause.name = { contains: where.nameContains, mode: 'insensitive' };
    if (where.category) whereClause.category = where.category;
    if (where.isActive !== undefined) whereClause.isActive = where.isActive;
    if (where.minPrice || where.maxPrice) {
      whereClause.price = {};
      if (where.minPrice) whereClause.price.gte = where.minPrice;
      if (where.maxPrice) whereClause.price.lte = where.maxPrice;
    }

    return prisma.product.findMany({
      where: whereClause,
      skip: offset,
      take: limit,
      orderBy: orderBy ? { [orderBy]: orderDirection || 'desc' } : undefined,
    });
  }
}
```

### Approach 3: Repository Pattern (Complex Projects)

Full abstraction for complex apps with raw SQL or multiple database types.

```typescript
// repositories/base.repository.ts

export interface PaginatedResult<T> {
  data: T[];
  totalCount: number;
  hasMore: boolean;
}

export abstract class BaseRepository<TEntity, TCreateInput, TUpdateInput, TFilter> {
  protected abstract tableName: string;
  protected abstract primaryKey: string;

  // Subclasses implement entity-specific mapping
  protected abstract mapRowToEntity(row: any): TEntity;
  protected abstract mapCreateInputToColumns(input: TCreateInput): Record<string, any>;
  protected abstract mapUpdateInputToColumns(input: TUpdateInput): Record<string, any>;
  protected abstract buildWhereClause(filter: Partial<TFilter>): { sql: string; params: any[] };

  // Whitelist columns for security
  protected abstract getAllowedOrderByColumns(): string[];

  async findById(id: string): Promise<TEntity | null> {
    const result = await this.query(
      `SELECT * FROM ${this.tableName} WHERE ${this.primaryKey} = $1`,
      [id]
    );
    return result.rows[0] ? this.mapRowToEntity(result.rows[0]) : null;
  }

  async findMany(filter: Partial<TFilter> & { limit?: number; offset?: number }): Promise<TEntity[]> {
    const { sql: whereSql, params } = this.buildWhereClause(filter);
    const orderBy = this.buildOrderByClause(filter);
    const limitOffset = this.buildLimitClause(filter);

    const query = `SELECT * FROM ${this.tableName} ${whereSql} ${orderBy} ${limitOffset}`;
    const result = await this.query(query, params);
    return result.rows.map((row) => this.mapRowToEntity(row));
  }

  async create(input: TCreateInput): Promise<TEntity> {
    const columns = this.mapCreateInputToColumns(input);
    const keys = Object.keys(columns);
    const values = Object.values(columns);
    const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');

    const query = `
      INSERT INTO ${this.tableName} (${keys.join(', ')})
      VALUES (${placeholders})
      RETURNING *
    `;
    const result = await this.query(query, values);
    return this.mapRowToEntity(result.rows[0]);
  }

  async updateById(id: string, input: TUpdateInput): Promise<TEntity | null> {
    const columns = this.mapUpdateInputToColumns(input);
    if (Object.keys(columns).length === 0) {
      return this.findById(id);
    }

    const sets = Object.keys(columns).map((key, i) => `${key} = $${i + 2}`);
    const values = [id, ...Object.values(columns)];

    const query = `
      UPDATE ${this.tableName}
      SET ${sets.join(', ')}, updated_at = NOW()
      WHERE ${this.primaryKey} = $1
      RETURNING *
    `;
    const result = await this.query(query, values);
    return result.rows[0] ? this.mapRowToEntity(result.rows[0]) : null;
  }

  async deleteById(id: string): Promise<boolean> {
    const result = await this.query(
      `DELETE FROM ${this.tableName} WHERE ${this.primaryKey} = $1`,
      [id]
    );
    return result.rowCount > 0;
  }

  protected buildOrderByClause(filter: any): string {
    const { orderBy, orderDirection = 'DESC' } = filter;
    if (!orderBy) return 'ORDER BY created_at DESC';

    const allowed = this.getAllowedOrderByColumns();
    if (!allowed.includes(orderBy)) {
      return 'ORDER BY created_at DESC';
    }

    const direction = orderDirection.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
    return `ORDER BY ${orderBy} ${direction}`;
  }

  protected buildLimitClause(filter: any): string {
    const limit = Math.min(filter.limit || 50, 2000);
    const offset = filter.offset || 0;
    return `LIMIT ${limit} OFFSET ${offset}`;
  }

  protected abstract query(sql: string, params?: any[]): Promise<{ rows: any[]; rowCount: number }>;
}
```

### Entity Mapping (When Needed)

For transforming database rows to domain entities:

```typescript
// utils/entity-mapper.ts

export interface FieldMapping {
  source: string;                    // Source field name
  target: string;                    // Target field name
  transform?: (value: any) => any;   // Optional transformation
  optional?: boolean;                // Skip if null/undefined
  defaultValue?: any;                // Default if null/undefined
}

export const FieldTransforms = {
  // JSON handling
  jsonToArray: (value: any): any[] => {
    if (!value) return [];
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') {
      try {
        return JSON.parse(value);
      } catch {
        return [];
      }
    }
    return [];
  },

  arrayToJson: (value: any[]): string | null =>
    value ? JSON.stringify(value) : null,

  // Boolean coercion
  toBoolean: (value: any): boolean =>
    value === true || value === 'true' || value === 1,

  // Naming conventions
  snakeToCamel: (value: string): string =>
    value.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase()),
};

// Simple mapping function (alternative to full EntityMapper class)
export function mapRow<T>(row: any, mappings: FieldMapping[]): T {
  const result: Record<string, any> = {};

  for (const mapping of mappings) {
    let value = row[mapping.source];

    if (value === null || value === undefined) {
      if (mapping.defaultValue !== undefined) {
        value = mapping.defaultValue;
      } else if (mapping.optional) {
        continue;
      }
    }

    if (mapping.transform && value != null) {
      value = mapping.transform(value);
    }

    result[mapping.target] = value;
  }

  return result as T;
}
```

---

## Browser/Server Split Architecture

Prevent Node.js modules from bundling into frontend code.

### Browser Bundle (No Node.js Dependencies)

```typescript
// browser.ts

// Types - pure TypeScript interfaces
export * from './types/index.js';

// Validation - Zod is browser-safe
export * from './validation/index.js';

// Errors - no Node.js dependencies
export * from './errors/index.js';

// Constants - pure data
export * from './constants/index.js';

// DO NOT export:
// - Database connections (pg, mysql, etc.)
// - Logging with file/OS access (pino, winston with file transports)
// - Anything using Buffer, fs, path, os, etc.
```

### Server Bundle (Full)

```typescript
// server.ts

// Everything from browser
export * from './browser.js';

// Plus server-only modules (if any exist in shared)
// export * from './repositories/index.js';
// export * from './services/index.js';
```

### Package.json Exports

```json
{
  "name": "@your-org/shared",
  "type": "module",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js",
      "require": "./dist/index.js",
      "default": "./dist/index.js"
    },
    "./browser": {
      "types": "./dist/browser.d.ts",
      "import": "./dist/browser.js",
      "require": "./dist/browser.js",
      "default": "./dist/browser.js"
    }
  }
}
```

**Note:** The `require` and `default` conditions are needed for Node.js/tsx CommonJS resolution compatibility. Without these, tools like `tsx` may fail to resolve the package correctly.

### Import Patterns

```typescript
// Frontend (React, Vite, etc.)
import {
  User,
  CreateUserRequestSchema,
  ValidationError,
  ApiResponse,
} from '@your-org/shared/browser';

// Backend (Express, Node.js)
import {
  User,
  CreateUserRequestSchema,
  ValidationError,
  // Same types, no risk of Node.js leaking to frontend
} from '@your-org/shared';
```

---

## Error Handling

### Base Error Class

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

### Application Error Classes

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

### Global Error Middleware

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

---

## Constants and Enums

### Single Source of Truth Pattern

```typescript
// constants/enums.ts

// Define as const arrays (source of truth)
export const ORDER_STATUSES = [
  'pending',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
] as const;

export const USER_ROLES = ['user', 'admin', 'moderator'] as const;

export const ORDER_DIRECTIONS = ['asc', 'desc'] as const;

// Derive TypeScript types from the arrays
export type OrderStatus = (typeof ORDER_STATUSES)[number];
export type UserRole = (typeof USER_ROLES)[number];
export type OrderDirection = (typeof ORDER_DIRECTIONS)[number];

// Create Zod schemas from the same source (in validation file)
// export const OrderStatusSchema = z.enum(ORDER_STATUSES);
// export const UserRoleSchema = z.enum(USER_ROLES);
```

**Why this pattern?**
- Single source of truth for valid values
- TypeScript type automatically stays in sync
- Zod schema uses same values - no duplication
- Easy to iterate over values at runtime
- Adding new values updates everything automatically

---

## Best Practices Summary

### Type Safety

1. **Separate concerns**: Domain entities, API requests, and filters should be distinct types
2. **Derive from schemas**: Use `z.infer<typeof Schema>` for compile-time + runtime safety
3. **Don't over-abstract**: Direct ORM types are fine when they match API needs
4. **Strict TypeScript**: Enable all strict compiler options (`strict: true`)

### Validation

1. **Validate at boundaries**: API entry points (middleware before controller)
2. **Use refinements**: `.refine()` for cross-field and business logic validation
3. **Detailed errors**: Include field paths and specific messages
4. **Coerce query params**: Query strings are always strings - coerce to proper types

### Data Access

1. **Start simple**: Direct ORM calls are fine for simple CRUD
2. **Add layers when needed**: Service layer for business logic, repository for complex queries
3. **Parameterize queries**: Never interpolate user input into SQL
4. **Whitelist columns**: For orderBy and filter fields, prevent SQL injection

### Error Handling

1. **Custom error classes**: With status codes and machine-readable codes
2. **Hide internal details**: Never expose stack traces or DB errors to users
3. **Operational vs bugs**: Know the difference - only crash on bugs
4. **Consistent format**: All API errors should have same structure

### Code Organization

1. **One file per domain**: Keep related types, schemas, and logic together
2. **Barrel exports**: Use index.ts for clean imports
3. **Split browser/server**: Prevent Node.js dependencies in frontend bundles
4. **Consistent naming**: Follow the naming convention table below

---

## Quick Reference

### Naming Conventions

| Layer | Naming Pattern | Example |
|-------|----------------|---------|
| Domain Entity | PascalCase | `Product`, `User` |
| Create Input | Create + Domain + Request | `CreateProductRequest` |
| Update Input | Update + Domain + Request | `UpdateProductRequest` |
| Filter Type | Domain + Filter | `ProductFilter` |
| Zod Schema | Domain/Purpose + Schema | `CreateProductRequestSchema` |
| Controller | Domain + Controller | `ProductController` |
| Service | Domain + Service | `ProductService` |
| Repository | Domain + Repository | `ProductRepository` |

### File Patterns

| Purpose | File Pattern |
|---------|--------------|
| Domain types | `types/{domain}.ts` |
| Common types | `types/common.ts`, `types/api.ts` |
| Domain validation | `validation/{domain}.ts` |
| Common validation | `validation/common.ts` |
| Error types | `errors/application-errors.ts` |
| Constants/enums | `constants/enums.ts` |
| Browser exports | `browser.ts` |
| Server exports | `server.ts` or `index.ts` |

### API Response Structure

```typescript
// Success
{
  "success": true,
  "data": { /* entity or array */ },
  "pagination": { /* optional */ }
}

// Error
{
  "success": false,
  "error": "Human-readable message",
  "code": "MACHINE_READABLE_CODE"
}
```
