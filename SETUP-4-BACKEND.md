# Phase 4: Backend Package Setup

## Step 16: Initialize Backend Package

```bash
cd packages/backend
npm init -y
```

Edit `packages/backend/package.json`:

```json
{
  "name": "@my-project/backend",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "db:generate": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:push": "prisma db push",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "@my-project/shared": "*"
  }
}
```

## Step 17: Install Backend Dependencies

Note when installing Prisma stay on version 6.

```bash
cd packages/backend
npm install express cors dotenv winston
npm install passport passport-local passport-jwt passport-google-oauth20 jsonwebtoken bcryptjs
npm install @prisma/client
npm install -D typescript tsx @types/node @types/express @types/cors
npm install -D @types/passport @types/passport-local @types/passport-jwt @types/passport-google-oauth20 @types/jsonwebtoken @types/bcryptjs
npm install -D prisma
```

## Step 18: Configure Backend TypeScript

Create `packages/backend/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

## Step 19: Initialize Prisma

```bash
cd packages/backend
npx prisma init
```

## Step 20: Configure Prisma Schema

Edit `packages/backend/prisma/schema.prisma`:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id            String    @id @default(cuid())
  email         String    @unique
  password      String?   // Optional for OAuth users
  name          String?
  googleId      String?   @unique
  avatarUrl     String?
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
  sessions      Session[]
}

model Session {
  id        String   @id @default(cuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  token     String   @unique
  expiresAt DateTime
  createdAt DateTime @default(now())
}
```

## Step 21: Create Environment File

Create `packages/backend/.env`:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/mydb?schema=public"
JWT_SECRET="your-super-secret-jwt-key-change-in-production"
PORT=3001

# Google OAuth (get these from Google Cloud Console)
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
GOOGLE_CALLBACK_URL="http://localhost:3001/api/auth/google/callback"
FRONTEND_URL="http://localhost:5173"
```

### Setting up Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to "APIs & Services" > "Credentials"
4. Click "Create Credentials" > "OAuth client ID"
5. Select "Web application" as the application type
6. Add authorized redirect URI: `http://localhost:3001/api/auth/google/callback`
7. Copy the Client ID and Client Secret to your `.env` file

## Step 22: Create Backend Source Files

Create directory structure:

```bash
mkdir -p packages/backend/src/{config,middleware,routes,services}
```

Create `packages/backend/src/index.ts`:

```typescript
import express from 'express'
import cors from 'cors'
import passport from 'passport'
import { config } from 'dotenv'

import { configurePassport } from './config/passport'
import { authRouter } from './routes/auth'
import { userRouter } from './routes/user'

config()

const app = express()
const PORT = process.env.PORT || 3001

// Middleware
app.use(cors({
  origin: 'http://localhost:5173',
  credentials: true
}))
app.use(express.json())

// Passport (stateless JWT - no sessions)
app.use(passport.initialize())
configurePassport(passport)

// Routes
app.use('/api/auth', authRouter)
app.use('/api/users', userRouter)

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' })
})

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`)
})
```

Create `packages/backend/src/config/passport.ts`:

```typescript
import { PassportStatic } from 'passport'
import { Strategy as LocalStrategy } from 'passport-local'
import { Strategy as JwtStrategy, ExtractJwt } from 'passport-jwt'
import { Strategy as GoogleStrategy } from 'passport-google-oauth20'
import bcrypt from 'bcryptjs'
import { prisma } from './database'

export function configurePassport(passport: PassportStatic) {
  // Local Strategy (for login with email/password)
  passport.use(new LocalStrategy(
    { usernameField: 'email' },
    async (email, password, done) => {
      try {
        const user = await prisma.user.findUnique({ where: { email } })

        if (!user || !user.password) {
          return done(null, false, { message: 'Invalid credentials' })
        }

        const isMatch = await bcrypt.compare(password, user.password)

        if (!isMatch) {
          return done(null, false, { message: 'Invalid credentials' })
        }

        return done(null, user)
      } catch (error) {
        return done(error)
      }
    }
  ))

  // JWT Strategy (for protected routes - stateless)
  passport.use(new JwtStrategy(
    {
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.JWT_SECRET || 'secret'
    },
    async (payload, done) => {
      try {
        const user = await prisma.user.findUnique({ where: { id: payload.sub } })

        if (!user) {
          return done(null, false)
        }

        return done(null, user)
      } catch (error) {
        return done(error)
      }
    }
  ))

  // Google OAuth Strategy
  passport.use(new GoogleStrategy(
    {
      clientID: process.env.GOOGLE_CLIENT_ID || '',
      clientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
      callbackURL: process.env.GOOGLE_CALLBACK_URL || 'http://localhost:3001/api/auth/google/callback'
    },
    async (accessToken, refreshToken, profile, done) => {
      try {
        // Check if user exists with this Google ID
        let user = await prisma.user.findUnique({
          where: { googleId: profile.id }
        })

        if (!user) {
          // Check if user exists with same email
          const email = profile.emails?.[0]?.value
          if (email) {
            user = await prisma.user.findUnique({ where: { email } })
            if (user) {
              // Link Google account to existing user
              user = await prisma.user.update({
                where: { id: user.id },
                data: {
                  googleId: profile.id,
                  avatarUrl: profile.photos?.[0]?.value
                }
              })
            }
          }
        }

        if (!user) {
          // Create new user
          user = await prisma.user.create({
            data: {
              email: profile.emails?.[0]?.value || '',
              name: profile.displayName,
              googleId: profile.id,
              avatarUrl: profile.photos?.[0]?.value
            }
          })
        }

        return done(null, user)
      } catch (error) {
        return done(error as Error)
      }
    }
  ))
}
```

Create `packages/backend/src/config/database.ts`:

```typescript
import { PrismaClient } from '@prisma/client'

export const prisma = new PrismaClient()
```

Create `packages/backend/src/middleware/auth.ts`:

```typescript
import { Request, Response, NextFunction } from 'express'
import passport from 'passport'

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  passport.authenticate('jwt', { session: false }, (err: any, user: any) => {
    if (err) {
      return res.status(500).json({ error: 'Authentication error' })
    }
    if (!user) {
      return res.status(401).json({ error: 'Unauthorized' })
    }
    req.user = user
    next()
  })(req, res, next)
}
```

Create `packages/backend/src/routes/auth.ts`:

```typescript
import { Router } from 'express'
import passport from 'passport'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { prisma } from '../config/database'
import type { ApiResponse, User } from '@my-project/shared'

export const authRouter = Router()

function generateToken(userId: string): string {
  return jwt.sign(
    { sub: userId },
    process.env.JWT_SECRET || 'secret',
    { expiresIn: '7d' }
  )
}

// Register
authRouter.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body

    const existingUser = await prisma.user.findUnique({ where: { email } })
    if (existingUser) {
      return res.status(400).json({
        success: false,
        error: 'Email already registered'
      } satisfies ApiResponse<never>)
    }

    const hashedPassword = await bcrypt.hash(password, 10)

    const user = await prisma.user.create({
      data: { email, password: hashedPassword, name }
    })

    const token = generateToken(user.id)
    const { password: _, ...userWithoutPassword } = user

    res.status(201).json({
      success: true,
      data: { user: userWithoutPassword, token }
    } satisfies ApiResponse<{ user: Omit<User, 'password'>; token: string }>)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Registration failed'
    } satisfies ApiResponse<never>)
  }
})

// Login with email/password
authRouter.post('/login', (req, res, next) => {
  passport.authenticate('local', { session: false }, (err: any, user: any, info: any) => {
    if (err) {
      return res.status(500).json({
        success: false,
        error: 'Login failed'
      } satisfies ApiResponse<never>)
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        error: info?.message || 'Invalid credentials'
      } satisfies ApiResponse<never>)
    }

    const token = generateToken(user.id)
    const { password: _, ...userWithoutPassword } = user

    res.json({
      success: true,
      data: { user: userWithoutPassword, token }
    } satisfies ApiResponse<{ user: Omit<User, 'password'>; token: string }>)
  })(req, res, next)
})

// Google OAuth - initiate
authRouter.get('/google',
  passport.authenticate('google', {
    scope: ['profile', 'email'],
    session: false
  })
)

// Google OAuth - callback
authRouter.get('/google/callback',
  passport.authenticate('google', {
    session: false,
    failureRedirect: `${process.env.FRONTEND_URL}/login?error=oauth_failed`
  }),
  (req, res) => {
    const user = req.user as any
    const token = generateToken(user.id)

    // Redirect to frontend with token
    res.redirect(`${process.env.FRONTEND_URL}/app/main?token=${token}`)
  }
)

// Logout (client-side only - just return success, client should discard token)
authRouter.post('/logout', (req, res) => {
  res.json({ success: true } satisfies ApiResponse<never>)
})
```

Create `packages/backend/src/routes/user.ts`:

```typescript
import { Router } from 'express'
import { prisma } from '../config/database'
import { requireAuth } from '../middleware/auth'
import type { ApiResponse, User } from '@my-project/shared'

export const userRouter = Router()

// Get current user
userRouter.get('/me', requireAuth, async (req, res) => {
  try {
    const user = req.user as User
    const { password: _, ...userWithoutPassword } = user as any

    res.json({
      success: true,
      data: userWithoutPassword
    } satisfies ApiResponse<Omit<User, 'password'>>)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to get user'
    } satisfies ApiResponse<never>)
  }
})

// Update current user
userRouter.patch('/me', requireAuth, async (req, res) => {
  try {
    const user = req.user as User
    const { name } = req.body

    const updatedUser = await prisma.user.update({
      where: { id: user.id },
      data: { name }
    })

    const { password: _, ...userWithoutPassword } = updatedUser

    res.json({
      success: true,
      data: userWithoutPassword
    } satisfies ApiResponse<Omit<User, 'password'>>)
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to update user'
    } satisfies ApiResponse<never>)
  }
})
```

## Step 23: Generate Prisma Client and Run Migrations

```bash
cd packages/backend
npx prisma generate
npx prisma migrate dev --name init
```

---

**Previous:** [Phase 3: Frontend Package Setup](./SETUP-3-FRONTEND.md)

**Next:** [Phase 5: Final Setup](./SETUP-5-FINAL.md)
