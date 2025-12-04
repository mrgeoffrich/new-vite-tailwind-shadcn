# Express.js - Complete Example

Full app initialization and controller implementation.

---

## App Initialization

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

---

## Complete Controller Example

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

## Key Patterns Summary

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
