# Pattern Installation Guide

This guide walks through implementing code organization patterns for the monorepo. Follow each step sequentially, running a build after each major section to catch issues early.

---

## Step 1: Shared Package Patterns

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

Fix any build errors before proceeding.

---

## Step 2: Express Backend Patterns

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

## Step 3: Prisma Patterns (Reference)

Review the Prisma migration workflow and best practices.

### File to Read:

- **PRISMA_PATTERNS.md** - Migration commands, common scenarios, best practices

---

## Step 4: Docker Setup (Optional)

If containerizing the application, follow the Docker setup guide.

### File to Read:

- **DOCKER_PATTERNS.md** - Dockerfile, docker-compose, environment configuration

---

## Important Notes

- **Read one section at a time** - Don't read ahead to avoid context overload
- **Run builds frequently** - Catch errors early after each major change
- **Choose your complexity level** - See SHARED_01_GETTING_STARTED.md for guidance on simple vs complex approaches
- **Start simple** - Use direct ORM calls initially, add layers only when needed
