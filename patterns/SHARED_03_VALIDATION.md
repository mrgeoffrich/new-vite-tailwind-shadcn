# Shared Package - Zod Validation

Patterns for runtime validation using Zod schemas.

---

## Basic Schema Structure

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

---

## Common Validation Patterns

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

---

## Cross-Field Validation with Refine

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

---

## Validation Helpers

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

---

## Validation Middleware Pattern

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
