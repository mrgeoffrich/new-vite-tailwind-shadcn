---
name: backend
description: Guidance for backend development with Express, Prisma, Passport.js authentication, and Zod validation. Use when adding routes, models, services, or middleware.
---

# Backend Development Skill

This skill provides guidance for making changes to the backend package in this monorepo.

## Architecture Overview

```
packages/backend/src/
├── index.ts                    # Server entry point
├── app.ts                      # Express app setup and middleware
├── config/
│   ├── database.ts             # Prisma client initialization
│   └── passport.ts             # Authentication strategies
├── controllers/
│   └── base.controller.ts      # Abstract base class with helpers
├── middleware/
│   ├── auth.ts                 # JWT authentication (requireAuth)
│   ├── error.middleware.ts     # Global error handling
│   └── validation.middleware.ts # Zod request validation
├── routes/
│   ├── index.ts                # Route registration
│   ├── auth.ts                 # Authentication routes
│   └── user.ts                 # User routes
├── services/                   # Business logic (add services here)
└── types/
    └── express.d.ts            # Express type extensions
```

## Key Technologies

- **Express 5** - Web framework
- **Prisma** - Database ORM (PostgreSQL)
- **Passport.js** - Authentication (JWT, Local, Google OAuth)
- **Zod** - Request validation
- **bcryptjs** - Password hashing
- **jsonwebtoken** - JWT generation/verification

---

## Implementation Patterns

### Adding a New Route File

1. Create the route file in `src/routes/`:

```typescript
// src/routes/posts.ts
import { Router } from 'express'
import { prisma } from '../config/database'
import { requireAuth } from '../middleware/auth'
import { validate, commonSchemas } from '../middleware/validation.middleware'
import { z } from 'zod'

const router = Router()

// Define validation schemas
const createPostSchema = z.object({
  title: z.string().min(1).max(255),
  content: z.string().min(1),
})

const updatePostSchema = z.object({
  title: z.string().min(1).max(255).optional(),
  content: z.string().min(1).optional(),
})

// GET /api/posts - List all posts
router.get('/', async (req, res, next) => {
  try {
    const posts = await prisma.post.findMany({
      orderBy: { createdAt: 'desc' },
    })
    res.json({ success: true, data: posts })
  } catch (error) {
    next(error)
  }
})

// GET /api/posts/:id - Get single post
router.get('/:id', validate({ params: commonSchemas.id }), async (req, res, next) => {
  try {
    const post = await prisma.post.findUnique({
      where: { id: req.params.id },
    })
    if (!post) {
      return res.status(404).json({ success: false, error: 'Post not found' })
    }
    res.json({ success: true, data: post })
  } catch (error) {
    next(error)
  }
})

// POST /api/posts - Create post (authenticated)
router.post('/', requireAuth, validate({ body: createPostSchema }), async (req, res, next) => {
  try {
    const post = await prisma.post.create({
      data: {
        ...req.body,
        authorId: req.user!.id,
      },
    })
    res.status(201).json({ success: true, data: post })
  } catch (error) {
    next(error)
  }
})

// PATCH /api/posts/:id - Update post (authenticated)
router.patch('/:id', requireAuth, validate({ params: commonSchemas.id, body: updatePostSchema }), async (req, res, next) => {
  try {
    const post = await prisma.post.findUnique({ where: { id: req.params.id } })
    if (!post) {
      return res.status(404).json({ success: false, error: 'Post not found' })
    }
    if (post.authorId !== req.user!.id) {
      return res.status(403).json({ success: false, error: 'Forbidden' })
    }
    const updated = await prisma.post.update({
      where: { id: req.params.id },
      data: req.body,
    })
    res.json({ success: true, data: updated })
  } catch (error) {
    next(error)
  }
})

// DELETE /api/posts/:id - Delete post (authenticated)
router.delete('/:id', requireAuth, validate({ params: commonSchemas.id }), async (req, res, next) => {
  try {
    const post = await prisma.post.findUnique({ where: { id: req.params.id } })
    if (!post) {
      return res.status(404).json({ success: false, error: 'Post not found' })
    }
    if (post.authorId !== req.user!.id) {
      return res.status(403).json({ success: false, error: 'Forbidden' })
    }
    await prisma.post.delete({ where: { id: req.params.id } })
    res.status(204).send()
  } catch (error) {
    next(error)
  }
})

export default router
```

2. Register the route in `src/routes/index.ts`:

```typescript
import postsRouter from './posts'

export function setupRoutes(app: Express): void {
  app.use('/api/auth', authRouter)
  app.use('/api/users', userRouter)
  app.use('/api/posts', postsRouter)  // Add new route
}
```

---

### Adding a New Prisma Model

1. Add the model to `prisma/schema.prisma`:

```prisma
model Post {
  id        String   @id @default(cuid())
  title     String
  content   String
  published Boolean  @default(false)
  authorId  String
  author    User     @relation(fields: [authorId], references: [id], onDelete: Cascade)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

// Don't forget to add the relation to User model:
model User {
  // ... existing fields
  posts     Post[]
}
```

2. Run migration commands:

```bash
npm run db:migrate -w @new-application/backend    # Create migration
npm run db:generate -w @new-application/backend   # Regenerate client
```

---

### Adding a Service Class

Create services in `src/services/` to extract business logic from routes:

```typescript
// src/services/post.service.ts
import { prisma } from '../config/database'
import { Prisma } from '@prisma/client'

export class PostService {
  async findAll(options?: {
    published?: boolean
    authorId?: string
    page?: number
    limit?: number
  }) {
    const { published, authorId, page = 1, limit = 20 } = options || {}

    const where: Prisma.PostWhereInput = {}
    if (published !== undefined) where.published = published
    if (authorId) where.authorId = authorId

    const [posts, total] = await Promise.all([
      prisma.post.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { author: { select: { id: true, name: true, avatarUrl: true } } },
      }),
      prisma.post.count({ where }),
    ])

    return { posts, total, page, limit }
  }

  async findById(id: string) {
    return prisma.post.findUnique({
      where: { id },
      include: { author: { select: { id: true, name: true, avatarUrl: true } } },
    })
  }

  async create(data: { title: string; content: string; authorId: string }) {
    return prisma.post.create({
      data,
      include: { author: { select: { id: true, name: true, avatarUrl: true } } },
    })
  }

  async update(id: string, data: { title?: string; content?: string; published?: boolean }) {
    return prisma.post.update({
      where: { id },
      data,
    })
  }

  async delete(id: string) {
    return prisma.post.delete({ where: { id } })
  }

  async isOwner(postId: string, userId: string): Promise<boolean> {
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: { authorId: true },
    })
    return post?.authorId === userId
  }
}

export const postService = new PostService()
```

---

### Adding Custom Middleware

```typescript
// src/middleware/rate-limit.middleware.ts
import { Request, Response, NextFunction } from 'express'

const requestCounts = new Map<string, { count: number; resetAt: number }>()

export function rateLimit(options: { windowMs: number; max: number }) {
  return (req: Request, res: Response, next: NextFunction) => {
    const key = req.ip || 'unknown'
    const now = Date.now()

    const record = requestCounts.get(key)

    if (!record || now > record.resetAt) {
      requestCounts.set(key, { count: 1, resetAt: now + options.windowMs })
      return next()
    }

    if (record.count >= options.max) {
      return res.status(429).json({
        success: false,
        error: { message: 'Too many requests', code: 'RATE_LIMITED' },
      })
    }

    record.count++
    next()
  }
}
```

Apply to specific routes:

```typescript
import { rateLimit } from '../middleware/rate-limit.middleware'

// Limit login attempts
router.post('/login', rateLimit({ windowMs: 15 * 60 * 1000, max: 5 }), ...)
```

---

### Adding Validation Schemas

Add reusable schemas to `validation.middleware.ts` or create domain-specific files:

```typescript
// In validation.middleware.ts or separate file
export const postSchemas = {
  create: z.object({
    title: z.string().min(1, 'Title is required').max(255),
    content: z.string().min(1, 'Content is required'),
  }),

  update: z.object({
    title: z.string().min(1).max(255).optional(),
    content: z.string().min(1).optional(),
    published: z.boolean().optional(),
  }),

  query: z.object({
    published: z.coerce.boolean().optional(),
    authorId: z.string().optional(),
    ...commonSchemas.pagination.shape,
  }),
}
```

---

### Extending the Base Controller

For complex routes, extend the base controller:

```typescript
// src/controllers/post.controller.ts
import { Request, Response } from 'express'
import { BaseController } from './base.controller'
import { postService } from '../services/post.service'

class PostController extends BaseController {
  list = this.handleAsync(async (req: Request, res: Response) => {
    const { page, limit } = this.getPagination(req)
    const { posts, total } = await postService.findAll({
      published: req.query.published as boolean | undefined,
      page,
      limit,
    })
    this.sendPaginatedResponse(res, posts, total, page, limit)
  })

  get = this.handleAsync(async (req: Request, res: Response) => {
    const post = await postService.findById(req.params.id)
    if (!post) {
      return this.sendNotFound(res, 'Post')
    }
    this.sendSuccess(res, post)
  })

  create = this.handleAsync(async (req: Request, res: Response) => {
    const post = await postService.create({
      ...req.body,
      authorId: req.user!.id,
    })
    this.sendCreated(res, post)
  })

  update = this.handleAsync(async (req: Request, res: Response) => {
    if (!await postService.isOwner(req.params.id, req.user!.id)) {
      return this.sendForbidden(res)
    }
    const post = await postService.update(req.params.id, req.body)
    this.sendSuccess(res, post)
  })

  delete = this.handleAsync(async (req: Request, res: Response) => {
    if (!await postService.isOwner(req.params.id, req.user!.id)) {
      return this.sendForbidden(res)
    }
    await postService.delete(req.params.id)
    this.sendNoContent(res)
  })
}

export const postController = new PostController()
```

Then in routes:

```typescript
router.get('/', postController.list)
router.get('/:id', validate({ params: commonSchemas.id }), postController.get)
router.post('/', requireAuth, validate({ body: postSchemas.create }), postController.create)
```

---

### Adding Shared Types

Add types to `packages/shared/src/types/`:

```typescript
// packages/shared/src/types/post.ts
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

export interface CreatePostInput {
  title: string
  content: string
}

export interface UpdatePostInput {
  title?: string
  content?: string
  published?: boolean
}
```

Export from `packages/shared/src/index.ts`:

```typescript
export * from './types/post'
```

---

## Response Format

All API responses follow this structure:

```typescript
// Success response
{
  success: true,
  data: T,
  pagination?: { page, limit, total, totalPages }
}

// Error response
{
  success: false,
  error: {
    message: string,
    code: string,
    details?: ValidationError[],
    timestamp: string,
    requestId?: string
  }
}
```

---

## Authentication

### Protected Routes

Use `requireAuth` middleware:

```typescript
import { requireAuth } from '../middleware/auth'

router.get('/me', requireAuth, handler)  // req.user is available
```

### Accessing Current User

```typescript
router.get('/me', requireAuth, async (req, res) => {
  // req.user contains the full User object from database
  const userId = req.user!.id
})
```

---

## Error Handling

Errors are automatically handled by the error middleware. Just throw or call `next(error)`:

```typescript
router.get('/:id', async (req, res, next) => {
  try {
    const item = await prisma.item.findUnique({ where: { id: req.params.id } })
    if (!item) {
      return res.status(404).json({ success: false, error: 'Not found' })
    }
    res.json({ success: true, data: item })
  } catch (error) {
    next(error)  // Handled by error middleware
  }
})
```

Prisma errors are automatically mapped:
- `P2002` (unique constraint) → 409 Conflict
- `P2025` (not found) → 404 Not Found
- `P2003` (foreign key) → 400 Bad Request

---

## Database Access

Import the Prisma client:

```typescript
import { prisma } from '../config/database'

// Common operations
const items = await prisma.item.findMany()
const item = await prisma.item.findUnique({ where: { id } })
const created = await prisma.item.create({ data })
const updated = await prisma.item.update({ where: { id }, data })
await prisma.item.delete({ where: { id } })

// With relations
const userWithPosts = await prisma.user.findUnique({
  where: { id },
  include: { posts: true },
})

// Transactions
const [user, post] = await prisma.$transaction([
  prisma.user.update({ where: { id }, data: { postCount: { increment: 1 } } }),
  prisma.post.create({ data: { title, content, authorId: id } }),
])
```

---

## Checklist for Backend Changes

- [ ] Create/update Prisma model if needed
- [ ] Run `npm run db:migrate -w @new-application/backend`
- [ ] Run `npm run db:generate -w @new-application/backend`
- [ ] Add validation schemas with Zod
- [ ] Create service class for business logic (optional but recommended)
- [ ] Create route file with handlers
- [ ] Register route in `src/routes/index.ts`
- [ ] Add shared types in `packages/shared/`
- [ ] Use `requireAuth` for protected routes
- [ ] Follow response format (`{ success, data/error }`)
- [ ] Test with Prisma Studio: `npm run db:studio -w @new-application/backend`
