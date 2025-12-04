# Express.js - Authentication Middleware

Patterns for multiple authentication strategies.

---

## API Key Authentication

```typescript
// src/middleware/auth.middleware.ts

import { Request, Response, NextFunction } from "express";
import { JWTService } from "../services/jwt.service.js";

/**
 * API Key Authentication
 * Validates X-API-Key header
 */
export async function authenticateApiKey(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const apiKeyHeader = req.headers["x-api-key"] as string | undefined;

  if (!apiKeyHeader || !apiKeyHeader.startsWith("your_prefix_")) {
    sendUnauthorizedError(res, "API key required", "API_KEY_MISSING");
    return;
  }

  const repository = getApiKeyRepository();
  const validationResult = await repository.validateApiKey(apiKeyHeader);

  if (!validationResult.isValid || !validationResult.apiKey) {
    sendUnauthorizedError(res, validationResult.reason || "Invalid API key", "INVALID_API_KEY");
    return;
  }

  req.apiKey = validationResult.apiKey;
  await repository.recordUsage(validationResult.apiKey.id);
  next();
}
```

---

## JWT Token Authentication

```typescript
/**
 * JWT Token Authentication
 * Validates Authorization header or cookie
 */
export async function requireUser(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  // Check both Authorization header and cookies
  const authHeader = req.headers.authorization;
  let token = JWTService.extractBearerToken(authHeader);

  if (!token && req.cookies?.access_token) {
    token = req.cookies.access_token;
  }

  if (!token) {
    sendUnauthorizedError(res, "Authentication required", "TOKEN_MISSING");
    return;
  }

  try {
    const payload = JWTService.verifyAccessToken(token);

    // Load user from database to verify they still exist
    const userRepo = getUserRepository();
    const user = await userRepo.findById(payload.userId);

    if (!user || !user.is_active) {
      sendUnauthorizedError(res, "User not found or inactive", "USER_INACTIVE");
      return;
    }

    req.user = user;
    req.userId = user.id;
    next();
  } catch (error) {
    sendUnauthorizedError(res, "Invalid token", "INVALID_TOKEN");
  }
}
```

---

## Either/Or Authentication

```typescript
/**
 * Either/Or Authentication
 * Accepts API key OR JWT token
 */
export async function authenticateEither(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  // Try API key first
  const apiKeyHeader = req.headers["x-api-key"] as string | undefined;
  if (apiKeyHeader && apiKeyHeader.startsWith("your_prefix_")) {
    const repository = getApiKeyRepository();
    const validationResult = await repository.validateApiKey(apiKeyHeader);

    if (validationResult.isValid && validationResult.apiKey) {
      req.apiKey = validationResult.apiKey;
      await repository.recordUsage(validationResult.apiKey.id);
      return next();
    }
  }

  // Fall back to JWT token
  const authHeader = req.headers.authorization;
  let token = JWTService.extractBearerToken(authHeader);

  if (!token && req.cookies?.access_token) {
    token = req.cookies.access_token;
  }

  if (!token) {
    sendUnauthorizedError(res, "Authentication required", "AUTH_REQUIRED");
    return;
  }

  try {
    const payload = JWTService.verifyAccessToken(token);
    const userRepo = getUserRepository();
    const user = await userRepo.findById(payload.userId);

    if (!user || !user.is_active) {
      sendUnauthorizedError(res, "User not found or inactive", "USER_INACTIVE");
      return;
    }

    req.user = user;
    req.userId = user.id;
    next();
  } catch {
    sendUnauthorizedError(res, "Invalid authentication", "INVALID_AUTH");
  }
}
```

---

## Optional API Key

```typescript
/**
 * Optional API Key
 * Attaches API key if present, but doesn't block request
 */
export async function optionalApiKey(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  const apiKeyHeader = req.headers["x-api-key"] as string | undefined;

  if (apiKeyHeader && apiKeyHeader.startsWith("your_prefix_")) {
    const repository = getApiKeyRepository();
    const validationResult = await repository.validateApiKey(apiKeyHeader);

    if (validationResult.isValid && validationResult.apiKey) {
      req.apiKey = validationResult.apiKey;
      await repository.recordUsage(validationResult.apiKey.id);
    }
  }

  next(); // Always continue, even if no API key
}

// Helper function
function sendUnauthorizedError(res: Response, message: string, code: string): void {
  res.status(401).json({
    error: {
      message,
      code,
      timestamp: new Date().toISOString(),
    },
  });
}
```
