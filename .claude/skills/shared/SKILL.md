---
name: shared
description: Guidance for the shared package containing TypeScript types, Zod validation schemas, and error classes used by both frontend and backend.
---

# Shared Package Skill

This skill provides guidance for making changes to the shared package that contains types, validation schemas, and utilities used by both frontend and backend.

## Package Structure

```
packages/shared/src/
├── index.ts                      # Main barrel export
├── browser.ts                    # Browser-safe exports
├── types/
│   ├── index.ts                  # Barrel export for types
│   ├── common.ts                 # BaseFilter, PaginationMeta, etc.
│   ├── user.ts                   # User-related types
│   └── api.ts                    # API response types
├── validation/
│   ├── index.ts                  # Barrel export for validation
│   ├── common.ts                 # Reusable Zod schemas
│   ├── user.ts                   # User validation schemas
│   └── helpers.ts                # Validation utility functions
├── errors/
│   ├── index.ts                  # Barrel export for errors
│   ├── base-error.ts             # Abstract BaseError class
│   └── application-errors.ts     # Domain-specific error classes
└── utils.ts                      # Helper utilities
```

## Key Principle: Browser-Safe Only

The shared package must contain **no Node.js dependencies**. Everything here runs in both browser and server environments. The only dependency is `zod` for validation.

---

## Implementation Patterns

### Adding New Types

1. Create or add to a type file in `src/types/`:

```typescript
// src/types/post.ts
import type { BaseFilter, PaginationMeta } from './common'

export interface Post {
  id: string
  title: string
  content: string
  published: boolean
  authorId: string
  createdAt: Date
  updatedAt: Date
}

export interface PostWithAuthor extends Post {
  author: {
    id: string
    name: string | null
    avatarUrl: string | null
  }
}

export interface CreatePostRequest {
  title: string
  content: string
}

export interface UpdatePostRequest {
  title?: string
  content?: string
  published?: boolean
}

export interface PostFilter extends BaseFilter {
  authorId?: string
  published?: boolean
  search?: string
}
```

2. Export from `src/types/index.ts`:

```typescript
export * from './common'
export * from './user'
export * from './api'
export * from './post'  // Add new export
```

3. Rebuild the package:

```bash
npm run build:shared
```

---

### Adding Validation Schemas

Create schemas that mirror your types for runtime validation:

```typescript
// src/validation/post.ts
import { z } from 'zod'
import { PaginationSchema, SortingSchema } from './common'

export const CreatePostRequestSchema = z.object({
  title: z.string().min(1, 'Title is required').max(255, 'Title too long'),
  content: z.string().min(1, 'Content is required'),
})

export const UpdatePostRequestSchema = z.object({
  title: z.string().min(1).max(255).optional(),
  content: z.string().min(1).optional(),
  published: z.boolean().optional(),
})

export const PostFilterSchema = PaginationSchema.merge(SortingSchema).extend({
  authorId: z.string().optional(),
  published: z.coerce.boolean().optional(),
  search: z.string().max(100).optional(),
})

// Infer types from schemas (alternative to manual type definitions)
export type CreatePostInput = z.infer<typeof CreatePostRequestSchema>
export type UpdatePostInput = z.infer<typeof UpdatePostRequestSchema>
export type PostFilterInput = z.infer<typeof PostFilterSchema>
```

Export from `src/validation/index.ts`:

```typescript
export * from './common'
export * from './user'
export * from './helpers'
export * from './post'  // Add new export
```

---

### Using Existing Common Schemas

The package provides reusable schemas in `validation/common.ts`:

```typescript
import {
  PaginationSchema,    // { page, limit }
  SortingSchema,       // { orderBy, orderDirection }
  IdParamSchema,       // { id }
  SearchSchema,        // { q }
  EmailSchema,         // string().email()
  PasswordSchema,      // string().min(8).max(72)
} from '@new-application/shared'

// Compose schemas
const MyFilterSchema = PaginationSchema.merge(SortingSchema).extend({
  status: z.enum(['active', 'inactive']).optional(),
})
```

---

### Adding Application Errors

Add domain-specific errors to `src/errors/application-errors.ts`:

```typescript
// Add to existing file
export class PostNotFoundError extends BaseError {
  constructor(postId: string) {
    super(
      `Post with ID ${postId} not found`,
      'POST_NOT_FOUND',
      404,
      true,
      { postId }
    )
  }

  getUserMessage(): string {
    return 'The requested post could not be found'
  }
}

export class PostPermissionError extends BaseError {
  constructor(userId: string, postId: string) {
    super(
      `User ${userId} does not have permission to modify post ${postId}`,
      'POST_PERMISSION_DENIED',
      403,
      true,
      { userId, postId }
    )
  }

  getUserMessage(): string {
    return 'You do not have permission to modify this post'
  }
}
```

Export from `src/errors/index.ts`:

```typescript
export * from './base-error'
export * from './application-errors'
```

---

### Adding Utility Functions

Add helpers to `src/utils.ts`:

```typescript
export function formatDate(date: Date): string {
  return date.toISOString()
}

export function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/--+/g, '-')
    .trim()
}

export function truncate(text: string, length: number): string {
  if (text.length <= length) return text
  return text.slice(0, length).trimEnd() + '...'
}

export function omit<T extends object, K extends keyof T>(
  obj: T,
  keys: K[]
): Omit<T, K> {
  const result = { ...obj }
  keys.forEach((key) => delete result[key])
  return result as Omit<T, K>
}

export function pick<T extends object, K extends keyof T>(
  obj: T,
  keys: K[]
): Pick<T, K> {
  const result = {} as Pick<T, K>
  keys.forEach((key) => {
    if (key in obj) result[key] = obj[key]
  })
  return result
}
```

---

## Existing Types Reference

### API Response Types

```typescript
// Standard API response wrapper
interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: string
  code?: string
  pagination?: PaginationMeta
}

// Discriminated unions for type narrowing
type ApiSuccessResponse<T> = { success: true; data: T; pagination?: PaginationMeta }
type ApiErrorResponse = { success: false; error: string; code?: string }
```

### Pagination Types

```typescript
interface PaginationMeta {
  page: number
  limit: number
  totalCount: number
  totalPages: number
  hasMore: boolean
}

interface PaginatedResult<T> {
  data: T[]
  pagination: PaginationMeta
}

interface BaseFilter {
  limit?: number
  offset?: number
  orderBy?: string
  orderDirection?: 'asc' | 'desc'
}
```

### User Types

```typescript
interface User {
  id: string
  email: string
  name: string | null
  avatarUrl: string | null
  createdAt: Date
  updatedAt: Date
}

interface AuthResponse {
  user: User
  token: string
}
```

---

## Existing Error Classes

| Error Class | Status Code | Use Case |
|-------------|-------------|----------|
| `ValidationError` | 400 | Invalid input data |
| `NotFoundError` | 404 | Resource not found |
| `ConflictError` | 409 | Duplicate/conflict |
| `AuthenticationError` | 401 | Not authenticated |
| `AuthorizationError` | 403 | Not authorized |
| `RateLimitError` | 429 | Too many requests |
| `DatabaseError` | 500 | Database failures |

Usage in backend:

```typescript
import { NotFoundError, AuthorizationError } from '@new-application/shared'

if (!post) {
  throw new NotFoundError('Post', postId)
}

if (post.authorId !== userId) {
  throw new AuthorizationError('edit this post')
}
```

---

## Validation Helpers

```typescript
import { validateData, formatZodErrors } from '@new-application/shared'

// Validate data against a schema
const result = validateData(CreatePostRequestSchema, requestBody)

if (!result.success) {
  const messages = formatZodErrors(result.errors)
  // messages: ['title: Title is required', 'content: Content is required']
}
```

---

## Usage Examples

### Frontend

```typescript
import type { User, Post, ApiResponse } from '@new-application/shared'
import { CreatePostRequestSchema } from '@new-application/shared'

// Type-safe API response handling
const response = await fetch('/api/posts')
const data: ApiResponse<Post[]> = await response.json()

if (data.success) {
  setPosts(data.data)
}

// Client-side validation before submit
const validation = CreatePostRequestSchema.safeParse(formData)
if (!validation.success) {
  setErrors(validation.error.flatten().fieldErrors)
  return
}
```

### Backend

```typescript
import type { Post, CreatePostRequest } from '@new-application/shared'
import { CreatePostRequestSchema } from '@new-application/shared'
import { NotFoundError } from '@new-application/shared'

// Use validation schema in middleware
router.post('/', validate({ body: CreatePostRequestSchema }), handler)

// Use types for Prisma results
const post: Post = await prisma.post.create({ data })

// Throw shared errors
if (!post) {
  throw new NotFoundError('Post', id)
}
```

---

## Build & Development

```bash
# Build shared package
npm run build:shared

# Watch mode during development
npm run dev  # Runs all packages including shared in watch mode
```

After adding new exports, both frontend and backend automatically pick up the changes when rebuilt.

---

## Export Structure

The package uses dual exports:

```typescript
// Main entry (index.ts) - re-exports browser bundle
import { User, ApiResponse } from '@new-application/shared'

// Browser-specific entry (browser.ts) - guaranteed browser-safe
import { User } from '@new-application/shared/browser'
```

Both are currently identical, but `browser.ts` can be used if server-specific exports are added to `index.ts` in the future.

---

## Checklist for Shared Package Changes

- [ ] Add types to `src/types/` with proper interfaces
- [ ] Add validation schemas to `src/validation/` mirroring types
- [ ] Export from appropriate `index.ts` barrel files
- [ ] Add error classes if domain needs custom errors
- [ ] Run `npm run build:shared` to compile
- [ ] Verify frontend can import: `import { NewType } from '@new-application/shared'`
- [ ] Verify backend can import the same way
- [ ] Keep everything browser-safe (no Node.js APIs)
