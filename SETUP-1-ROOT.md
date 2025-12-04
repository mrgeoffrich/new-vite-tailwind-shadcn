# Phase 1: Root Project Structure

A full-stack TypeScript monorepo with:
- **frontend**: Vite + React + Tailwind CSS v4 + shadcn + React Router
- **backend**: Express.js + Passport.js (Local + Google OAuth) + Prisma ORM
- **shared**: Shared types and utilities

Features:
- Login page with email/password and Google OAuth
- Protected `/app/main` route after authentication

---

## Step 1: Create Root Project Structure

```bash
mkdir my-project
cd my-project
npm init -y
```

## Step 2: Configure Workspaces

Important: Make sure the shared package is built first before any others.

Edit root `package.json`:

```json
{
  "name": "my-project",
  "private": true,
  "workspaces": [
    "packages/*"
  ],
  "scripts": {
    "dev": "npm run dev --workspaces --if-present",
    "dev:frontend": "npm run dev -w @my-project/frontend",
    "dev:backend": "npm run dev -w @my-project/backend",
    "build": "npm run build -w @my-project/shared && npm run build -w @my-project/frontend && npm run build -w @my-project/backend",
    "build:shared": "npm run build -w @my-project/shared",
    "lint": "npm run lint --workspaces --if-present"
  }
}
```

## Step 3: Create Package Directories

```bash
mkdir -p packages/frontend packages/backend packages/shared
```

---

**Next:** [Phase 2: Shared Package Setup](./SETUP-2-SHARED.md)
