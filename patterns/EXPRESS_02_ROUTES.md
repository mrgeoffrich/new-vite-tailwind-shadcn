# Express.js - Route Organization

Patterns for organizing Express routes.

---

## Route File Pattern

```typescript
// src/routes/users.routes.ts

import { Router } from "express";
import { authenticateEither } from "../middleware/auth.middleware.js";
import { validate, validateId, validatePagination } from "../middleware/validation.middleware.js";
import { moderateRateLimiter } from "../middleware/rate-limit.middleware.js";
import { UsersController } from "../controllers/users.controller.js";
import { userSchemas } from "../validation/user.schemas.js";

const router: Router = Router();

// Lazy controller instantiation - avoids premature instantiation
const getController = () => new UsersController();

/**
 * Create new user
 * POST /api/users
 */
router.post("/",
  moderateRateLimiter,
  authenticateEither,
  validate({ body: userSchemas.create }),
  (req, res) => getController().create(req, res)
);

/**
 * List all users (paginated)
 * GET /api/users
 */
router.get("/",
  moderateRateLimiter,
  authenticateEither,
  validatePagination,
  (req, res) => getController().list(req, res)
);

/**
 * Get user by ID
 * GET /api/users/:id
 */
router.get("/:id",
  moderateRateLimiter,
  authenticateEither,
  validateId,
  (req, res) => getController().getById(req, res)
);

/**
 * Update user
 * PUT /api/users/:id
 */
router.put("/:id",
  moderateRateLimiter,
  authenticateEither,
  validateId,
  validate({ body: userSchemas.update }),
  (req, res) => getController().update(req, res)
);

/**
 * Delete user
 * DELETE /api/users/:id
 */
router.delete("/:id",
  moderateRateLimiter,
  authenticateEither,
  validateId,
  (req, res) => getController().delete(req, res)
);

export { router as userRoutes };
```

---

## Central Route Registration

```typescript
// src/routes/index.ts

import { Express } from "express";
import { healthRoutes } from "./health.routes.js";
import { authRoutes } from "./auth.routes.js";
import { userRoutes } from "./users.routes.js";
import { apiKeyRoutes } from "./api-keys.routes.js";

export function setupRoutes(app: Express): void {
  // Health check routes (no auth required)
  app.use("/", healthRoutes);

  // Authentication routes
  app.use("/auth", authRoutes);

  // API routes with authentication
  app.use("/api/users", userRoutes);
  app.use("/api/keys", apiKeyRoutes);
}
```
