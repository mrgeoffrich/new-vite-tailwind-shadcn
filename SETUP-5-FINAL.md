# Phase 5: Final Setup

## Step 24: Install All Dependencies from Root

```bash
cd my-project  # root directory
npm install
```

## Step 25: Build Shared Package

```bash
npm run build -w @my-project/shared
```

## Step 26: Run Development Servers

In separate terminals:

```bash
# Terminal 1 - Backend
npm run dev:backend

# Terminal 2 - Frontend
npm run dev:frontend
```

Or run both concurrently (install concurrently first):

```bash
npm install -D concurrently
```

Add to root `package.json` scripts:

```json
{
  "scripts": {
    "dev:all": "concurrently \"npm run dev:backend\" \"npm run dev:frontend\""
  }
}
```

## Step 27: Copy Documentation Files

Copy the setup and pattern documentation files to the new project root:

```bash
cd my-project  # root directory
cp /path/to/template-folder/SETUP.md .
cp /path/to/template-folder/EXPRESS_PATTERNS.md .
cp /path/to/template-folder/SHARED_TYPES_AND_REPOSITORY_PATTERNS.md .
cp /path/to/template-folder/EXTRA_SETUP_STEPS.md .
```

---

## Quick Reference: All CLI Commands

```bash
# Create project structure
mkdir my-project && cd my-project
npm init -y
mkdir -p packages/frontend packages/backend packages/shared

# Setup shared package
cd packages/shared
npm init -y
npm install -D typescript
# (manual config edits)
npm run build

# Setup frontend
cd ../frontend
npm create vite@latest . -- --template react-ts
npm install tailwindcss @tailwindcss/vite react-router-dom
npm install -D @types/node
mkdir -p src/{contexts,pages,components}
# (manual config edits)
npx shadcn@latest init
npx shadcn@latest add button card input label avatar badge separator -y

# Setup backend
cd ../backend
npm init -y
npm install express cors dotenv passport passport-local passport-jwt passport-google-oauth20 jsonwebtoken bcryptjs @prisma/client
npm install -D typescript tsx @types/node @types/express @types/cors @types/passport @types/passport-local @types/passport-jwt @types/passport-google-oauth20 @types/jsonwebtoken @types/bcryptjs prisma
npx prisma init
# (manual config edits + .env with Google OAuth credentials)
npx prisma generate
npx prisma migrate dev --name init

# Install all from root
cd ../../
npm install
npm run build -w @my-project/shared

# Run development
npm run dev:backend  # Terminal 1
npm run dev:frontend # Terminal 2
```

---

## Auth Flow Summary

1. **Login Page** (`/login`): Users see a login form with:
   - Google OAuth button (redirects to `/api/auth/google`)
   - Email/password form (posts to `/api/auth/login`)

2. **Google OAuth Flow**:
   - User clicks "Continue with Google"
   - Redirected to Google consent screen
   - Google redirects back to `/api/auth/google/callback`
   - Backend creates/finds user, generates JWT
   - Redirects to `/app/main?token=<jwt>`
   - Frontend extracts token from URL and stores it

3. **Protected Routes**:
   - `ProtectedRoute` component checks for valid user
   - Redirects to `/login` if not authenticated
   - `/app/main` shows the main dashboard after login

---

**Previous:** [Phase 4: Backend Package Setup](./SETUP-4-BACKEND.md)

**Back to:** [Setup Guide Index](./SETUP.md)
