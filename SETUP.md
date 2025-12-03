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

## Instructions

Read SETUP-1-ROOT.md first, and add it to the todo list. Execute the todo list.

Make sure you run a build after this is done and fix any issues before progressing.

Read SETUP-2-SHARED.md, and add it to the todo list. Execute the todo list.

Make sure you run a build after this is done and fix any issues before progressing.

Read SETUP-3-FRONTEND.md, and add it to the todo list. Execute the todo list.

Make sure you run a build after this is done and fix any issues before progressing.

Read SETup-4-BACKEND.md, and add it to the todo list. Execute the todo list.

Make sure you run a build after this is done and fix any issues before progressing.

Read SETUP-5-FINAL.md, and add it to the todo list. Execute the todo list.

Make sure you run a build after this is done and fix any issues before progressing.

Note: Don't read ahead, only read in the context for one step at a time as to not overwhelm the context window.
