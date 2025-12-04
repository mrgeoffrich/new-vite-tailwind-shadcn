# Shared Package - Browser/Server Split

Prevent Node.js modules from bundling into frontend code.

---

## Browser Bundle (No Node.js Dependencies)

```typescript
// browser.ts

// Types - pure TypeScript interfaces
export * from './types/index.js';

// Validation - Zod is browser-safe
export * from './validation/index.js';

// Errors - no Node.js dependencies
export * from './errors/index.js';

// Constants - pure data
export * from './constants/index.js';

// DO NOT export:
// - Database connections (pg, mysql, etc.)
// - Logging with file/OS access (pino, winston with file transports)
// - Anything using Buffer, fs, path, os, etc.
```

---

## Server Bundle (Full)

```typescript
// server.ts

// Everything from browser
export * from './browser.js';

// Plus server-only modules (if any exist in shared)
// export * from './repositories/index.js';
// export * from './services/index.js';
```

---

## Package.json Exports

```json
{
  "name": "@your-org/shared",
  "type": "module",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js",
      "require": "./dist/index.js",
      "default": "./dist/index.js"
    },
    "./browser": {
      "types": "./dist/browser.d.ts",
      "import": "./dist/browser.js",
      "require": "./dist/browser.js",
      "default": "./dist/browser.js"
    }
  }
}
```

**Note:** The `require` and `default` conditions are needed for Node.js/tsx CommonJS resolution compatibility. Without these, tools like `tsx` may fail to resolve the package correctly.

---

## Import Patterns

```typescript
// Frontend (React, Vite, etc.)
import {
  User,
  CreateUserRequestSchema,
  ValidationError,
  ApiResponse,
} from '@your-org/shared/browser';

// Backend (Express, Node.js)
import {
  User,
  CreateUserRequestSchema,
  ValidationError,
  // Same types, no risk of Node.js leaking to frontend
} from '@your-org/shared';
```
