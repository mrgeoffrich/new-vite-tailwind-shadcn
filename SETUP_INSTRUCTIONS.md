# Monorepo Setup Guide

A full-stack TypeScript monorepo with:
- **frontend**: Vite + React + Tailwind CSS v4 + shadcn + React Router
- **backend**: Express.js + Passport.js (Local + Google OAuth) + Prisma ORM
- **shared**: Shared types and utilities

Features:
- Login page with email/password and Google OAuth
- Protected `/app/main` route after authentication

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
