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

## Step 26: Copy Documentation Files

Copy the setup and pattern documentation files to the new project root (all the files in @pattens/)

```bash
cd my-project  # root directory
cp /path/to/template-folder/patters/* .
```

## Step 27: Copy the Claude skills

Copy the folders under @skills_to_copy/ into the .claude/skills folder in the new application.

## Step 27: Update all npm pages to latest

Go through all the packages and make sure we are running the latest version of all the npm packages..

## Step 28: Run a /init on the new project

Get Claude to create a new CLAUDE.md for the new project.

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
