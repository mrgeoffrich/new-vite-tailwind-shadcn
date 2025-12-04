# Shared Package Patterns Installation Guide

This guide walks through implementing code organization patterns for the shared package. This provides the foundational types, validation, and error handling used across your monorepo.

---

## Shared Package Patterns

Implement the shared package types, validation, and error handling patterns.

### Files to Read (in order):

1. **SHARED_01_GETTING_STARTED.md** - Architecture overview, when to use patterns, directory structure
2. **SHARED_02_TYPES.md** - Type definition patterns (domain entities, requests, filters)
3. **SHARED_03_VALIDATION.md** - Zod validation patterns and middleware
4. **SHARED_04_DATA_ACCESS.md** - Data access approaches (direct ORM, service layer, repository)
5. **SHARED_05_BROWSER_SERVER.md** - Browser/server split architecture
6. **SHARED_06_ERRORS.md** - Error handling with custom error classes
7. **SHARED_07_REFERENCE.md** - Constants, naming conventions, best practices

### After Implementation:

```bash
npm run build
```

Fix any build errors before proceeding to Express patterns.

---

## Important Notes

- **Read one section at a time** - Don't read ahead to avoid context overload
- **Run builds frequently** - Catch errors early after each major change
- **Choose your complexity level** - See SHARED_01_GETTING_STARTED.md for guidance on simple vs complex approaches
- **Start simple** - Use direct ORM calls initially, add layers only when needed

---

## Next Steps

After completing shared package patterns, continue with:
- **INSTALL_EXPRESS_PATTERNS.md** - Express backend route organization, middleware, and controllers
