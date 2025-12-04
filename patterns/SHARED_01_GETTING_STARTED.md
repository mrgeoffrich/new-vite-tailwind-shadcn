# Shared Package - Getting Started

Overview of patterns for shared types, validation, and database access in TypeScript monorepos.

---

## When to Use These Patterns

### Complexity Spectrum

Choose your approach based on project complexity:

| Complexity | Characteristics | Recommended Approach |
|------------|-----------------|---------------------|
| **Simple** | <10 tables, CRUD-heavy, single developer | Direct ORM calls in controllers, minimal abstraction |
| **Medium** | 10-30 tables, some complex queries, small team | Service layer with ORM, shared types/validation |
| **Complex** | 30+ tables, complex business logic, multiple teams | Full repository pattern with entity mapping |

### Decision Guide

**Use direct ORM/Prisma when:**
- Schema is simple with mostly 1:1 mapping to API types
- No complex field transformations needed
- Team is small and conventions are clear
- Rapid prototyping is priority

**Use repository pattern when:**
- Database columns need transformation (snake_case → camelCase)
- Complex queries are reused across multiple places
- Need to abstract database vendor
- Multiple developers need clear contracts

**Always use:**
- Shared types between frontend/backend
- Zod validation at API boundaries
- Custom error classes with status codes
- Browser/server split for shared packages

---

## Architecture Overview

The shared library serves as the single source of truth for types, validation, and optionally data access across a monorepo.

### Core Principles

- **Domain-driven organization**: One file per domain entity
- **Layered types**: Separate types for API requests, domain entities, and optionally database rows
- **Runtime + compile-time safety**: Zod schemas for validation, TypeScript for type checking
- **Browser/server separation**: Explicit bundles to prevent Node.js modules leaking to frontend

### Type Flow (Full)

```
DATABASE SCHEMA
    ↓
DatabaseRow (raw types, optional if using ORM with good types)
    ↓
EntityMapper (field transformation, optional if no mapping needed)
    ↓
DomainEntity (business types)
    ↓
ZodSchema (runtime validation)
    ↓
API Response / Frontend Types
```

### Type Flow (Simplified with ORM like Prisma)

```
PRISMA SCHEMA
    ↓
Generated Prisma Types (automatic)
    ↓
DomainEntity (may be same as Prisma type, or sanitized version)
    ↓
ZodSchema (for API input validation)
    ↓
API Response Types
```

---

## Directory Structure

### Shared Package Structure

```
packages/shared/src/
├── index.ts                      # Default export (usually re-exports browser)
├── browser.ts                    # Browser-safe exports only
├── server.ts                     # Server exports with Node.js modules (optional)
│
├── types/                        # TypeScript interfaces
│   ├── index.ts                  # Barrel export
│   ├── {domain}.ts               # Per-domain types (user.ts, order.ts, etc.)
│   ├── api.ts                    # API response wrapper types
│   └── common.ts                 # Pagination, sorting, base filter types
│
├── validation/                   # Zod schemas
│   ├── index.ts                  # Barrel export
│   ├── {domain}.ts               # Per-domain schemas
│   ├── common.ts                 # Reusable schema patterns
│   └── helpers.ts                # validateData(), formatZodErrors()
│
├── errors/                       # Structured errors
│   ├── index.ts                  # Barrel export
│   ├── base-error.ts             # Abstract BaseError class
│   └── application-errors.ts     # ValidationError, NotFoundError, etc.
│
└── constants/                    # Constants (optional)
    └── enums.ts                  # Enum arrays and derived types
```

### Backend Package Structure

```
packages/backend/src/
├── index.ts                      # Express app setup
│
├── config/                       # Configuration
│   ├── env.ts                    # Zod-validated environment config
│   ├── database.ts               # Database client singleton
│   └── passport.ts               # Auth strategies (if using)
│
├── controllers/                  # Request handlers
│   ├── base.controller.ts        # Base class with helpers (optional)
│   └── {domain}.controller.ts    # Per-domain controllers
│
├── middleware/                   # Express middleware
│   ├── validation.ts             # Zod validation middleware
│   ├── auth.ts                   # Authentication middleware
│   └── error.ts                  # Global error handler
│
├── routes/                       # Route definitions
│   └── {domain}.ts               # Per-domain routes
│
├── services/                     # Business logic (optional layer)
│   └── {domain}.service.ts
│
└── repositories/                 # Data access (optional, for complex projects)
    ├── base.repository.ts
    └── {domain}.repository.ts
```
