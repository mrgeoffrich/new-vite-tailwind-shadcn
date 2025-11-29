# Monorepo Setup Guide

A full-stack TypeScript monorepo with:
- **frontend**: Vite + React + Tailwind CSS v4 + shadcn + React Router
- **backend**: Express.js + Passport.js (Local + Google OAuth) + Prisma ORM
- **shared**: Shared types and utilities

Features:
- Login page with email/password and Google OAuth
- Protected `/app/main` route after authentication

---

## Setup Phases

Follow these phases in order to set up the complete monorepo:

| Phase | Description | Steps |
|-------|-------------|-------|
| [Phase 1: Root Project Structure](./SETUP-1-ROOT.md) | Create project and configure workspaces | 1-3 |
| [Phase 2: Shared Package Setup](./SETUP-2-SHARED.md) | Set up shared types and utilities | 4-7 |
| [Phase 3: Frontend Package Setup](./SETUP-3-FRONTEND.md) | Vite + React + Tailwind + shadcn + Auth | 8-15.6 |
| [Phase 4: Backend Package Setup](./SETUP-4-BACKEND.md) | Express + Passport + Prisma | 16-23 |
| [Phase 5: Final Setup](./SETUP-5-FINAL.md) | Install dependencies and run | 24-27 |

---

## Project Structure

```
my-project/
├── package.json              # Root package.json with workspaces
├── packages/
│   ├── frontend/             # Vite + React + Tailwind + shadcn
│   │   ├── package.json
│   │   ├── vite.config.ts
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── App.tsx
│   │       ├── main.tsx
│   │       ├── index.css
│   │       ├── components/
│   │       │   ├── ui/       # shadcn components
│   │       │   └── ProtectedRoute.tsx
│   │       ├── contexts/
│   │       │   └── AuthContext.tsx
│   │       └── pages/
│   │           ├── LoginPage.tsx
│   │           └── MainPage.tsx
│   ├── backend/              # Express + Passport (Local + Google) + Prisma
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── .env
│   │   ├── prisma/
│   │   │   └── schema.prisma
│   │   └── src/
│   │       ├── index.ts
│   │       ├── config/
│   │       │   ├── database.ts
│   │       │   └── passport.ts
│   │       ├── middleware/
│   │       │   └── auth.ts
│   │       ├── routes/
│   │       │   ├── auth.ts
│   │       │   └── user.ts
│   │       └── services/
│   └── shared/               # Shared types and utilities
│       ├── package.json
│       ├── tsconfig.json
│       └── src/
│           ├── index.ts
│           ├── types.ts
│           └── utils.ts
```

---

## Quick Start

If you want a quick overview of all commands, see the [Quick Reference section in Phase 5](./SETUP-5-FINAL.md#quick-reference-all-cli-commands).

## Auth Flow

See the [auth flow summary in Phase 5](./SETUP-5-FINAL.md#auth-flow-summary).
