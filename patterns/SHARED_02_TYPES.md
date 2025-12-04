# Shared Package - Type Definitions

Patterns for defining TypeScript types in your shared package.

---

## Separate Types by Purpose

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

---

## Common Types (Reusable)

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

---

## API Response Types

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

---

## Database Row Types (When Needed)

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
