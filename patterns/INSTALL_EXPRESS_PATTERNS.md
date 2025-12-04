# Express Backend Patterns Installation Guide

This guide walks through implementing Express.js patterns for routes, middleware, controllers, and backend infrastructure.

**Prerequisites:** Complete `INSTALL_SHARED_PATTERNS.md` first and ensure the shared package builds successfully.

---

## Express Backend Patterns

Implement the Express.js route organization and middleware patterns.

### Files to Read (in order):

1. **EXPRESS_01_PROJECT_SETUP.md** - Project structure, shared types, Express type extensions
2. **EXPRESS_02_ROUTES.md** - Route file organization, central registration
3. **EXPRESS_03_AUTH.md** - Authentication middleware (API key, JWT, either/or)
4. **EXPRESS_04_VALIDATION.md** - Request validation with Zod
5. **EXPRESS_05_ERRORS.md** - Error handling middleware
6. **EXPRESS_06_RESPONSES.md** - Pagination and response formatting
7. **EXPRESS_07_MIDDLEWARE.md** - Rate limiting and logging middleware
8. **EXPRESS_08_BASE_CONTROLLER.md** - Base controller pattern with helpers
9. **EXPRESS_09_COMPLETE_EXAMPLE.md** - Full app setup and controller example

### After Implementation:

```bash
npm run build
```

Fix any build errors before proceeding.

---

## Important Notes

- **Read one section at a time** - Don't read ahead to avoid context overload
- **Run builds frequently** - Catch errors early after each major change
- **Test endpoints** - Verify authentication, validation, and error handling work as expected
- **Start simple** - Add complexity (rate limiting, advanced auth) only when needed
