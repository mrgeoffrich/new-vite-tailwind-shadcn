# Phase 2: Shared Package Setup

## Step 4: Initialize Shared Package

```bash
cd packages/shared
npm init -y
```

Edit `packages/shared/package.json`:

```json
{
  "name": "@my-project/shared",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch"
  }
}
```

## Step 5: Configure Shared TypeScript

Create `packages/shared/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "declaration": true,
    "declarationMap": true,
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

## Step 6: Create Shared Source Files

Create `packages/shared/src/index.ts`:

```typescript
// Export all shared types and utilities
export * from './types'
export * from './utils'
```

Create `packages/shared/src/types.ts`:

```typescript
export interface User {
  id: string
  email: string
  name: string | null
  createdAt: Date
  updatedAt: Date
}

export interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: string
}
```

Create `packages/shared/src/utils.ts`:

```typescript
export function formatDate(date: Date): string {
  return date.toISOString()
}
```

## Step 7: Install Shared Dependencies

```bash
cd packages/shared
npm install -D typescript
npm run build
```

---

**Previous:** [Phase 1: Root Project Structure](./SETUP-1-ROOT.md)

**Next:** [Phase 3: Frontend Package Setup](./SETUP-3-FRONTEND.md)
