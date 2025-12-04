# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is an instructional repository containing prompts and patterns for scaffolding new TypeScript monorepo projects with Claude. It is not a working codebase itself - it provides templates and guidance for creating new projects.

## How This Repository Works

The repository provides a two-step scaffolding process:

1. **Project Scaffolding** - Use `SETUP.md` to create a new monorepo at a specified path with:
   - `packages/frontend/` - Vite + React 19 + Tailwind CSS v4 + shadcn/ui + React Router
   - `packages/backend/` - Express 5 + Passport.js (JWT, Local, Google OAuth) + Prisma ORM
   - `packages/shared/` - Shared TypeScript types, Zod validation, error classes

2. **Pattern Implementation** - Use `patterns/INSTALL_PATTERNS.md` in the new project to implement code organization patterns

## Key Files and Their Purpose

| File | Purpose |
|------|---------|
| `SETUP.md` | Entry point - orchestrates reading SETUP-1 through SETUP-5 sequentially |
| `SETUP-1-ROOT.md` | Root package.json with npm workspaces configuration |
| `SETUP-2-SHARED.md` | Shared package with types and utilities |
| `SETUP-3-FRONTEND.md` | React frontend with auth context, login page, protected routes |
| `SETUP-4-BACKEND.md` | Express backend with Passport strategies, Prisma schema, JWT auth |
| `SETUP-5-FINAL.md` | Final setup steps, copy patterns and skills to new project |
| `patterns/` | Post-scaffolding patterns for code organization |
| `skills_to_copy/` | Claude Code skills to copy into new projects' `.claude/skills/` |

## Pattern Documentation

The `patterns/` directory contains implementation guides copied to new projects:

- `SHARED_TYPES_AND_REPOSITORY_PATTERNS.md` - Type definitions, Zod validation, data access patterns (direct ORM vs service layer vs repository)
- `EXPRESS_PATTERNS.md` - Route organization, authentication middleware, validation, error handling, rate limiting, base controller pattern
- `PRISMA_PATTERNS.md` - Migration workflow, common scenarios, naming conventions

## Generated Project Structure

New projects created from this template have:

```
my-project/
├── packages/
│   ├── frontend/         # React + Vite + shadcn
│   ├── backend/          # Express + Prisma + Passport
│   └── shared/           # Types, validation, errors
├── .claude/skills/       # Claude Code skills for context
└── patterns/             # Reference documentation
```

## Commands for Generated Projects

When working in a generated project (not this template repo):

```bash
# Root commands
npm install                    # Install all workspace dependencies
npm run build                  # Build shared → frontend → backend
npm run dev                    # Run all packages in watch mode
npm run dev:frontend           # Run frontend only (port 5173)
npm run dev:backend            # Run backend only (port 3001)

# Backend-specific (from packages/backend)
npm run db:migrate             # Create and apply Prisma migration
npm run db:generate            # Regenerate Prisma client
npm run db:push                # Push schema without migration
npm run db:studio              # Open Prisma Studio GUI
```

## Architecture Decisions in Generated Projects

- **Shared package builds first** - Frontend and backend depend on @my-project/shared
- **Browser/server split** - Shared package has `browser.ts` for frontend-safe exports
- **Stateless JWT auth** - No server sessions, tokens in Authorization header
- **Zod validation** - Schemas in shared package, validated via middleware
- **API response format** - `{ success: boolean, data?: T, error?: string, pagination?: {...} }`
