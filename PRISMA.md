# Prisma Migration Guide

## Quick Reference

```bash
# All commands run from packages/backend directory
cd packages/backend

# Generate Prisma Client (after schema changes, no migration)
npx prisma generate

# Create and apply migration (development)
npx prisma migrate dev --name <migration_name>

# Apply pending migrations (production)
npx prisma migrate deploy

# Reset database (WARNING: deletes all data)
npx prisma migrate reset

# View database in browser
npx prisma studio
```

---

## Development Workflow

### 1. Making Schema Changes

Edit `prisma/schema.prisma`, then create a migration:

```bash
npx prisma migrate dev --name add_user_avatar
```

This command:
- Creates a new migration file in `prisma/migrations/`
- Applies the migration to your database
- Regenerates Prisma Client

### 2. Naming Conventions

Use descriptive, snake_case names:

```bash
npx prisma migrate dev --name add_posts_table
npx prisma migrate dev --name add_user_email_index
npx prisma migrate dev --name rename_title_to_name
npx prisma migrate dev --name add_cascade_delete_to_sessions
```

### 3. When to Use Each Command

| Command | Use Case |
|---------|----------|
| `migrate dev` | Development - creates migration and applies it |
| `migrate deploy` | Production/CI - applies existing migrations only |
| `migrate reset` | Development - reset DB and replay all migrations |
| `db push` | Prototyping - sync schema without creating migration |
| `generate` | Only regenerate client (no DB changes) |

---

## Production Deployment

### Applying Migrations

```bash
npx prisma migrate deploy
```

- Only applies pending migrations
- Does NOT create new migrations
- Safe for production use
- Fails if there are schema conflicts

### CI/CD Pipeline Example

```yaml
# Example GitHub Actions step
- name: Apply database migrations
  run: npx prisma migrate deploy
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

---

## Common Scenarios

### Adding a New Field

```prisma
model User {
  id    String @id @default(cuid())
  email String @unique
  phone String? // New optional field
}
```

```bash
npx prisma migrate dev --name add_user_phone
```

### Adding a Required Field to Existing Table

Option 1: Make it optional first, backfill, then make required

```prisma
// Step 1: Add as optional
model User {
  role String?
}
```

```bash
npx prisma migrate dev --name add_user_role_nullable
```

```typescript
// Step 2: Backfill data
await prisma.user.updateMany({
  where: { role: null },
  data: { role: 'user' }
})
```

```prisma
// Step 3: Make required
model User {
  role String @default("user")
}
```

```bash
npx prisma migrate dev --name make_user_role_required
```

Option 2: Add with default value directly

```prisma
model User {
  role String @default("user")
}
```

### Renaming a Field

Prisma will treat this as drop + create. To preserve data:

1. Create a custom migration:

```bash
npx prisma migrate dev --name rename_title_to_name --create-only
```

2. Edit the generated SQL file:

```sql
-- Instead of DROP + ADD, use:
ALTER TABLE "Post" RENAME COLUMN "title" TO "name";
```

3. Apply the migration:

```bash
npx prisma migrate dev
```

### Deleting a Field

```prisma
model User {
  id    String @id
  email String
  // removed: oldField String
}
```

```bash
npx prisma migrate dev --name remove_old_field
```

### Adding an Index

```prisma
model User {
  id        String   @id
  email     String   @unique
  createdAt DateTime @default(now())

  @@index([createdAt])
}
```

```bash
npx prisma migrate dev --name add_created_at_index
```

### Adding Relations

```prisma
model User {
  id    String @id @default(cuid())
  posts Post[]
}

model Post {
  id       String @id @default(cuid())
  authorId String
  author   User   @relation(fields: [authorId], references: [id], onDelete: Cascade)
}
```

```bash
npx prisma migrate dev --name add_posts_relation
```

---

## Handling Migration Issues

### Migration Conflicts

If you see "Migration failed to apply cleanly":

```bash
# Option 1: Reset database (dev only, loses data)
npx prisma migrate reset

# Option 2: Mark migration as applied (if DB is already in sync)
npx prisma migrate resolve --applied <migration_name>

# Option 3: Roll back manually and retry
```

### Schema Drift

When your database doesn't match your schema:

```bash
# Check for drift
npx prisma migrate diff --from-schema-datamodel prisma/schema.prisma --to-schema-datasource prisma/schema.prisma

# Fix by creating a new migration
npx prisma migrate dev --name fix_schema_drift
```

### Baseline an Existing Database

If you have an existing database without migrations:

```bash
# Create initial migration without applying
npx prisma migrate dev --name init --create-only

# Mark it as already applied
npx prisma migrate resolve --applied <migration_folder_name>
```

---

## Best Practices

### 1. Never Edit Applied Migrations

Once a migration is in version control or applied to production, don't modify it. Create a new migration instead.

### 2. Review Generated SQL

```bash
# Create migration without applying
npx prisma migrate dev --name my_change --create-only

# Review the SQL in prisma/migrations/<timestamp>_my_change/migration.sql

# Then apply
npx prisma migrate dev
```

### 3. Keep Migrations Small

One logical change per migration:
- Adding a table
- Adding a column
- Creating an index

### 4. Test Migrations

```bash
# Reset and replay all migrations to verify they work
npx prisma migrate reset
```

### 5. Version Control

Always commit:
- `prisma/schema.prisma`
- `prisma/migrations/` directory

Never commit:
- `.env` files with real credentials

### 6. Backup Before Production Migrations

```bash
# PostgreSQL example
pg_dump -h hostname -U username -d dbname > backup.sql
```

---

## Useful Commands

```bash
# Format schema file
npx prisma format

# Validate schema
npx prisma validate

# View migration status
npx prisma migrate status

# Open Prisma Studio (database GUI)
npx prisma studio

# Seed database
npx prisma db seed
```

---

## Database Seeding

Create `prisma/seed.ts`:

```typescript
import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
  const hashedPassword = await bcrypt.hash('password123', 10)

  await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {},
    create: {
      email: 'admin@example.com',
      name: 'Admin User',
      password: hashedPassword,
    },
  })
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
```

Add to `package.json`:

```json
{
  "prisma": {
    "seed": "tsx prisma/seed.ts"
  }
}
```

Run seed:

```bash
npx prisma db seed
```

---

## Environment Variables

### Development (.env)

```env
DATABASE_URL="postgresql://user:password@localhost:5432/blingtv?schema=public"
```

### Production

Use connection pooling for serverless:

```env
DATABASE_URL="postgresql://user:password@host:5432/db?schema=public&connection_limit=5"
```

For services like Supabase, Neon, or PlanetScale, use their provided connection strings.
