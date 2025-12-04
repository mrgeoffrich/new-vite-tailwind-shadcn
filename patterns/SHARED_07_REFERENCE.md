# Shared Package - Quick Reference

Constants, best practices, and naming conventions.

---

## Constants and Enums

### Single Source of Truth Pattern

```typescript
// constants/enums.ts

// Define as const arrays (source of truth)
export const ORDER_STATUSES = [
  'pending',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
] as const;

export const USER_ROLES = ['user', 'admin', 'moderator'] as const;

export const ORDER_DIRECTIONS = ['asc', 'desc'] as const;

// Derive TypeScript types from the arrays
export type OrderStatus = (typeof ORDER_STATUSES)[number];
export type UserRole = (typeof USER_ROLES)[number];
export type OrderDirection = (typeof ORDER_DIRECTIONS)[number];

// Create Zod schemas from the same source (in validation file)
// export const OrderStatusSchema = z.enum(ORDER_STATUSES);
// export const UserRoleSchema = z.enum(USER_ROLES);
```

**Why this pattern?**
- Single source of truth for valid values
- TypeScript type automatically stays in sync
- Zod schema uses same values - no duplication
- Easy to iterate over values at runtime
- Adding new values updates everything automatically

---

## Best Practices Summary

### Type Safety

1. **Separate concerns**: Domain entities, API requests, and filters should be distinct types
2. **Derive from schemas**: Use `z.infer<typeof Schema>` for compile-time + runtime safety
3. **Don't over-abstract**: Direct ORM types are fine when they match API needs
4. **Strict TypeScript**: Enable all strict compiler options (`strict: true`)

### Validation

1. **Validate at boundaries**: API entry points (middleware before controller)
2. **Use refinements**: `.refine()` for cross-field and business logic validation
3. **Detailed errors**: Include field paths and specific messages
4. **Coerce query params**: Query strings are always strings - coerce to proper types

### Data Access

1. **Start simple**: Direct ORM calls are fine for simple CRUD
2. **Add layers when needed**: Service layer for business logic, repository for complex queries
3. **Parameterize queries**: Never interpolate user input into SQL
4. **Whitelist columns**: For orderBy and filter fields, prevent SQL injection

### Error Handling

1. **Custom error classes**: With status codes and machine-readable codes
2. **Hide internal details**: Never expose stack traces or DB errors to users
3. **Operational vs bugs**: Know the difference - only crash on bugs
4. **Consistent format**: All API errors should have same structure

### Code Organization

1. **One file per domain**: Keep related types, schemas, and logic together
2. **Barrel exports**: Use index.ts for clean imports
3. **Split browser/server**: Prevent Node.js dependencies in frontend bundles
4. **Consistent naming**: Follow the naming convention table below

---

## Naming Conventions

| Layer | Naming Pattern | Example |
|-------|----------------|---------|
| Domain Entity | PascalCase | `Product`, `User` |
| Create Input | Create + Domain + Request | `CreateProductRequest` |
| Update Input | Update + Domain + Request | `UpdateProductRequest` |
| Filter Type | Domain + Filter | `ProductFilter` |
| Zod Schema | Domain/Purpose + Schema | `CreateProductRequestSchema` |
| Controller | Domain + Controller | `ProductController` |
| Service | Domain + Service | `ProductService` |
| Repository | Domain + Repository | `ProductRepository` |

---

## File Patterns

| Purpose | File Pattern |
|---------|--------------|
| Domain types | `types/{domain}.ts` |
| Common types | `types/common.ts`, `types/api.ts` |
| Domain validation | `validation/{domain}.ts` |
| Common validation | `validation/common.ts` |
| Error types | `errors/application-errors.ts` |
| Constants/enums | `constants/enums.ts` |
| Browser exports | `browser.ts` |
| Server exports | `server.ts` or `index.ts` |

---

## API Response Structure

```typescript
// Success
{
  "success": true,
  "data": { /* entity or array */ },
  "pagination": { /* optional */ }
}

// Error
{
  "success": false,
  "error": "Human-readable message",
  "code": "MACHINE_READABLE_CODE"
}
```
