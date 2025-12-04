# Express.js - Request Validation

Patterns for request validation using Zod.

---

## Validation Middleware

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

function formatZodErrors(error: ZodError): Array<{ field: string; message: string }> {
  return error.issues.map((issue) => ({
    field: issue.path.join('.'),
    message: issue.message,
  }));
}
```

---

## Common Validation Schemas

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

---

## API-Specific Schemas

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
