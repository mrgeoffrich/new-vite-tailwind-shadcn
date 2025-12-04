# Express.js - Rate Limiting & Logging

Patterns for rate limiting and request logging middleware.

---

## Rate Limiting

### Multiple Rate Limiters

```typescript
// src/middleware/rate-limit.middleware.ts

import rateLimit from "express-rate-limit";
import { Request, Response } from "express";
import { config } from "../config/index.js";
import { logger } from "../utils/logger.js";

interface RateLimiterOptions {
  windowMs: number;
  max: number;
  message?: string;
  keyGenerator?: (req: Request) => string;
}

function createRateLimiter(options: RateLimiterOptions) {
  return rateLimit({
    windowMs: options.windowMs,
    max: options.max,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: options.keyGenerator || getKeyGenerator(),
    handler: (req: Request, res: Response) => {
      const key = options.keyGenerator ? options.keyGenerator(req) : getKeyGenerator()(req);
      logger.warn(`Rate limit exceeded for ${key}`, {
        ip: req.ip,
        path: req.path,
        apiKey: req.apiKey?.name,
      });

      res.status(429).json({
        error: {
          message: options.message || "Too many requests, please try again later",
          code: "RATE_LIMIT_EXCEEDED",
          retryAfter: res.get("Retry-After"),
        },
      });
    },
  });
}

function getKeyGenerator() {
  return (req: Request): string => {
    // Use API key ID if authenticated, otherwise use IP
    if (req.apiKey) {
      return `api-key:${req.apiKey.id}`;
    }
    return `ip:${req.ip || req.socket.remoteAddress || "unknown"}`;
  };
}
```

---

### Pre-configured Rate Limiters

```typescript
/**
 * Strict rate limiter for sensitive endpoints (5 req/15 min)
 * Use for: login, password reset, account creation
 */
export const strictRateLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  message: "Too many attempts, please try again later",
});

/**
 * Moderate rate limiter for general API endpoints (100 req/min)
 * Use for: most CRUD operations
 */
export const moderateRateLimiter = createRateLimiter({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
});

/**
 * Lenient rate limiter for read-only endpoints (200 req/min)
 * Use for: list endpoints, search, health checks
 */
export const lenientRateLimiter = createRateLimiter({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 200,
});

/**
 * Dynamic rate limiter - higher limits for authenticated users
 */
export function createDynamicRateLimiter() {
  return rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: (req: Request): number => {
      if (req.apiKey || req.user) {
        return 200; // Authenticated users get higher limits
      }
      return 50; // Unauthenticated users get lower limits
    },
    keyGenerator: getKeyGenerator(),
    standardHeaders: true,
    legacyHeaders: false,
  });
}
```

---

## Request Logging

```typescript
// src/middleware/logging.middleware.ts

import { Request, Response, NextFunction } from "express";
import { randomUUID } from "crypto";
import { logger } from "../utils/logger.js";
import { config } from "../config/index.js";

export function loggingMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  // Generate unique request ID
  req.id = randomUUID();
  req.startTime = Date.now();

  const requestLog: Record<string, unknown> = {
    id: req.id,
    method: req.method,
    url: req.url,
    path: req.path,
    query: req.query,
    ip: req.ip || req.socket.remoteAddress,
    userAgent: req.get("user-agent"),
    apiKey: req.apiKey?.name,
  };

  // Don't log sensitive data in production
  if (config.server.isDevelopment) {
    requestLog.headers = sanitizeHeaders(req.headers);
    if (req.body && Object.keys(req.body).length > 0) {
      requestLog.body = sanitizeBody(req.body);
    }
  }

  logger.info(`Request started: ${req.method} ${req.path}`, requestLog);

  // Capture response
  const originalSend = res.send;
  res.send = function (data): Response {
    res.send = originalSend;

    const duration = Date.now() - (req.startTime || 0);
    const responseLog = {
      id: req.id,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      contentLength: res.get("content-length"),
    };

    if (res.statusCode >= 400) {
      logger.warn(`Request failed: ${req.method} ${req.path}`, responseLog);
    } else {
      logger.info(`Request completed: ${req.method} ${req.path}`, responseLog);
    }

    return originalSend.call(this, data);
  };

  next();
}
```

---

## Sanitization Helpers

```typescript
// Redact sensitive headers
function sanitizeHeaders(headers: Record<string, unknown>): Record<string, unknown> {
  const sanitized = { ...headers };
  const sensitiveHeaders = ["authorization", "x-api-key", "cookie", "x-auth-token"];

  for (const header of sensitiveHeaders) {
    if (sanitized[header]) {
      sanitized[header] = "[REDACTED]";
    }
  }

  return sanitized;
}

// Redact sensitive body fields
function sanitizeBody(body: Record<string, unknown>): Record<string, unknown> {
  const sanitized = { ...body };
  const sensitiveFields = ["password", "token", "secret", "apiKey", "privateKey"];

  for (const field of sensitiveFields) {
    if (field in sanitized) {
      sanitized[field] = "[REDACTED]";
    }
  }

  // Recursively sanitize nested objects
  for (const key in sanitized) {
    if (typeof sanitized[key] === "object" && sanitized[key] !== null) {
      sanitized[key] = sanitizeBody(sanitized[key] as Record<string, unknown>);
    }
  }

  return sanitized;
}
```
