# Express.js - Project Setup

Project structure and shared types for Express.js APIs.

---

## Project Structure

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

## Shared Types

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

---

## Express Type Extensions

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
