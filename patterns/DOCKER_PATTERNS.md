# Docker Setup Guide

A guide for containerizing the monorepo application with Docker and Docker Compose.

## Quick Start

After following this guide, you can run:

```bash
# Start all services (database + backend + frontend)
docker compose up -d --build

# View logs
docker compose logs -f

# Stop all services
docker compose down

# Stop and remove volumes (reset database)
docker compose down -v
```

---

## 1. Environment Configuration

Create `.env` in the project root with database credentials:

```env
# Database Configuration
POSTGRES_USER=myapp_user
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=myapp_db
DATABASE_URL="postgresql://myapp_user:your_secure_password_here@db:5432/myapp_db?schema=public"

# Backend Configuration
JWT_SECRET="your-super-secret-jwt-key-change-in-production"
PORT=3001

# Google OAuth (optional - get from Google Cloud Console)
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
GOOGLE_CALLBACK_URL="http://localhost:3001/api/auth/google/callback"
FRONTEND_URL="http://localhost:5173"

# Node Environment
NODE_ENV=development
```

Add `.env` to `.gitignore`:

```gitignore
# Environment files
.env
.env.local
.env.*.local
```

Create `.env.example` as a template (commit this):

```env
# Database Configuration
POSTGRES_USER=myapp_user
POSTGRES_PASSWORD=change_this_password
POSTGRES_DB=myapp_db
DATABASE_URL="postgresql://myapp_user:change_this_password@db:5432/myapp_db?schema=public"

# Backend Configuration
JWT_SECRET="change-this-secret-in-production"
PORT=3001

# Google OAuth (optional)
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
GOOGLE_CALLBACK_URL="http://localhost:3001/api/auth/google/callback"
FRONTEND_URL="http://localhost:5173"

# Node Environment
NODE_ENV=development
```

---

## 2. Prisma Configuration for Docker

**Important (Prisma 7+):** The database URL must be configured in `prisma.config.ts`, NOT in `schema.prisma`.

Ensure `packages/backend/prisma/schema.prisma` has NO url property:

```prisma
datasource db {
  provider = "postgresql"
}
```

The URL is configured in `packages/backend/prisma.config.ts`:

```typescript
import "dotenv/config";
import { defineConfig, env } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: env("DATABASE_URL"),
  },
});
```

---

## 3. Docker Compose Configuration

Create `docker-compose.yml` in the project root:

```yaml
services:
  # PostgreSQL Database
  db:
    image: postgres:16-alpine
    container_name: myapp-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5433:5432"  # Use 5433 externally to avoid conflicts with local PostgreSQL
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Backend API
  backend:
    build:
      context: .
      dockerfile: packages/backend/Dockerfile
    container_name: myapp-backend
    restart: unless-stopped
    environment:
      DATABASE_URL: ${DATABASE_URL}
      JWT_SECRET: ${JWT_SECRET}
      PORT: ${PORT}
      NODE_ENV: ${NODE_ENV}
      GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
      GOOGLE_CLIENT_SECRET: ${GOOGLE_CLIENT_SECRET}
      GOOGLE_CALLBACK_URL: ${GOOGLE_CALLBACK_URL}
      FRONTEND_URL: ${FRONTEND_URL}
    ports:
      - "3002:3001"  # Use 3002 externally to avoid conflicts
    depends_on:
      db:
        condition: service_healthy

  # Frontend (Development with HMR)
  frontend:
    build:
      context: .
      dockerfile: packages/frontend/Dockerfile
    container_name: myapp-frontend
    restart: unless-stopped
    environment:
      NODE_ENV: ${NODE_ENV}
    ports:
      - "5173:5173"
    depends_on:
      - backend

volumes:
  postgres_data:
```

**Note:** External ports are mapped to avoid conflicts with locally running services:
- Database: `5433` → `5432` (internal)
- Backend: `3002` → `3001` (internal)

---

## 4. Backend Dockerfile

Create `packages/backend/Dockerfile`:

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy root package files
COPY package*.json ./
COPY packages/shared/package*.json ./packages/shared/
COPY packages/backend/package*.json ./packages/backend/

# Install dependencies
RUN npm ci

# Copy source files
COPY packages/shared ./packages/shared
COPY packages/backend ./packages/backend

# Build shared package first
RUN npm run build -w @my-project/shared

# Generate Prisma client BEFORE backend build (required for TypeScript types)
RUN npx prisma generate --schema=packages/backend/prisma/schema.prisma

# Build backend
RUN npm run build -w @my-project/backend

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

# Copy root package files
COPY package*.json ./
COPY packages/shared/package*.json ./packages/shared/
COPY packages/backend/package*.json ./packages/backend/

# Install all dependencies (need prisma CLI for migrations)
RUN npm ci

# Copy built files
COPY --from=builder /app/packages/shared/dist ./packages/shared/dist
COPY --from=builder /app/packages/backend/dist ./packages/backend/dist
COPY --from=builder /app/packages/backend/prisma ./packages/backend/prisma
COPY --from=builder /app/packages/backend/prisma.config.ts ./packages/backend/prisma.config.ts
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma

WORKDIR /app/packages/backend

# Copy and set up entrypoint script
COPY packages/backend/docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x docker-entrypoint.sh

# Expose port
EXPOSE 3001

# Run migrations and start server
ENTRYPOINT ["./docker-entrypoint.sh"]
```

**Key points:**
- Prisma client must be generated BEFORE TypeScript compilation
- `prisma.config.ts` must be copied to the runner stage for migrations
- All dependencies are installed (not `--omit=dev`) because prisma CLI is needed for migrations

---

## 5. Backend Entrypoint Script

Create `packages/backend/docker-entrypoint.sh`:

```bash
#!/bin/sh
set -e

echo "Running database migrations..."
npx prisma migrate deploy

echo "Starting server..."
exec node dist/index.js
```

**Important (Windows users):** Ensure the script has Unix line endings (LF, not CRLF):

```bash
# Convert line endings if needed
sed -i 's/\r$//' packages/backend/docker-entrypoint.sh

# Or use dos2unix
dos2unix packages/backend/docker-entrypoint.sh
```

---

## 6. Frontend Dockerfile

Create `packages/frontend/Dockerfile`:

### Development Dockerfile (with HMR)

```dockerfile
FROM node:20-alpine

WORKDIR /app

# Copy root package files
COPY package*.json ./
COPY packages/shared/package*.json ./packages/shared/
COPY packages/frontend/package*.json ./packages/frontend/

# Install dependencies
RUN npm ci

# Copy source files
COPY packages/shared ./packages/shared
COPY packages/frontend ./packages/frontend

# Build shared package
RUN npm run build -w @my-project/shared

WORKDIR /app/packages/frontend

# Expose Vite dev server port
EXPOSE 5173

# Start Vite dev server with host flag for Docker
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
```

### Production Dockerfile (with nginx)

For production, create `packages/frontend/Dockerfile.prod`:

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy root package files
COPY package*.json ./
COPY packages/shared/package*.json ./packages/shared/
COPY packages/frontend/package*.json ./packages/frontend/

# Install dependencies
RUN npm ci

# Copy source files
COPY packages/shared ./packages/shared
COPY packages/frontend ./packages/frontend

# Build shared package first, then frontend
RUN npm run build -w @my-project/shared
RUN npm run build -w @my-project/frontend

# Production stage with nginx
FROM nginx:alpine AS runner

# Copy built assets
COPY --from=builder /app/packages/frontend/dist /usr/share/nginx/html

# Copy nginx config for SPA routing
COPY packages/frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

Create `packages/frontend/nginx.conf`:

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;

    # SPA routing - serve index.html for all routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to backend
    location /api {
        proxy_pass http://backend:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## 7. Production Docker Compose

Create `docker-compose.prod.yml` for production:

```yaml
services:
  db:
    image: postgres:16-alpine
    container_name: myapp-db
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    # No exposed ports in production - internal only

  backend:
    build:
      context: .
      dockerfile: packages/backend/Dockerfile
    container_name: myapp-backend
    restart: always
    environment:
      DATABASE_URL: ${DATABASE_URL}
      JWT_SECRET: ${JWT_SECRET}
      PORT: 3001
      NODE_ENV: production
      GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
      GOOGLE_CLIENT_SECRET: ${GOOGLE_CLIENT_SECRET}
      GOOGLE_CALLBACK_URL: ${GOOGLE_CALLBACK_URL}
      FRONTEND_URL: ${FRONTEND_URL}
    depends_on:
      db:
        condition: service_healthy

  frontend:
    build:
      context: .
      dockerfile: packages/frontend/Dockerfile.prod
    container_name: myapp-frontend
    restart: always
    ports:
      - "80:80"
    depends_on:
      - backend

volumes:
  postgres_data:
```

Run production build:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

---

## 8. Docker Ignore Files

Create `.dockerignore` in project root:

```dockerignore
# Dependencies
node_modules
**/node_modules

# Build outputs
**/dist
**/build

# Development files
.git
.gitignore
*.md
!README.md

# Environment files
.env
.env.*
!.env.example

# IDE
.vscode
.idea

# OS files
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*

# Test files
**/*.test.ts
**/*.spec.ts
**/coverage

# Docker files (avoid recursive copy)
Dockerfile*
docker-compose*
```

---

## 9. Useful Commands

```bash
# Build and start all services
docker compose up -d --build

# View logs for specific service
docker compose logs -f backend
docker compose logs -f db

# Execute command in running container
docker compose exec backend sh
docker compose exec db psql -U myapp_user -d myapp_db

# Run Prisma commands in container
docker compose exec backend npx prisma studio
docker compose exec backend npx prisma migrate dev --name add_feature

# Rebuild single service
docker compose up -d --build backend

# Remove everything including volumes
docker compose down -v --rmi all

# Check service health
docker compose ps
```

---

## 10. Database Management

### Connect to database directly

```bash
docker compose exec db psql -U myapp_user -d myapp_db
```

### Backup database

```bash
docker compose exec db pg_dump -U myapp_user myapp_db > backup.sql
```

### Restore database

```bash
cat backup.sql | docker compose exec -T db psql -U myapp_user -d myapp_db
```

### Reset database

```bash
docker compose down -v
docker compose up -d
```

---

## 11. Troubleshooting

### Port already in use

If you see "port is already allocated", change the external port mapping in `docker-compose.yml`:

```yaml
ports:
  - "5433:5432"  # Change 5433 to another available port
```

### Database connection refused

Wait for healthcheck to pass:
```bash
docker compose logs db
docker compose ps  # Check if db is healthy
```

### Entrypoint script fails with "no such file or directory"

This usually means Windows CRLF line endings. Fix with:
```bash
sed -i 's/\r$//' packages/backend/docker-entrypoint.sh
docker compose up -d --build backend
```

### Frontend can't reach backend

In development, ensure Vite proxy is configured. In production, nginx proxies `/api` requests.

### Permission issues on Linux

```bash
sudo chown -R $USER:$USER .
```

---

## Checklist for Docker Setup

- [ ] Create `.env` with database credentials
- [ ] Add `.env` to `.gitignore`
- [ ] Create `.env.example` template
- [ ] Create `docker-compose.yml`
- [ ] Create `packages/backend/Dockerfile`
- [ ] Create `packages/backend/docker-entrypoint.sh` with Unix line endings
- [ ] Create `packages/frontend/Dockerfile`
- [ ] Create `.dockerignore`
- [ ] Test with `docker compose up -d --build`
- [ ] Check logs with `docker compose logs backend`
- [ ] Verify database connection with `docker compose exec db psql -U myapp_user -d myapp_db`
- [ ] For production: create `docker-compose.prod.yml` and `Dockerfile.prod`
