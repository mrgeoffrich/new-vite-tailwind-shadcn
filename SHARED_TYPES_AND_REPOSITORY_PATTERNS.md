# Shared Types & Repository Patterns

A comprehensive guide to patterns for shared types and database access in TypeScript monorepos, extracted from real-world production code.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Directory Structure](#directory-structure)
3. [Type Definition Patterns](#type-definition-patterns)
4. [Zod Validation Patterns](#zod-validation-patterns)
5. [Repository Patterns](#repository-patterns)
6. [Entity Mapping](#entity-mapping)
7. [Query Building](#query-building)
8. [Browser/Server Split Architecture](#browserserver-split-architecture)
9. [Error Handling](#error-handling)
10. [Constants and Enums](#constants-and-enums)
11. [Best Practices Summary](#best-practices-summary)

---

## Architecture Overview

The shared library serves as the single source of truth for types, validation, and data access across a monorepo. Key principles:

- **Domain-driven organization**: One file per domain entity
- **Layered types**: Separate types for database rows, domain entities, and API requests
- **Runtime + compile-time safety**: Zod schemas for validation, TypeScript for type checking
- **Browser/server separation**: Explicit bundles to prevent Node.js modules leaking to frontend

### Type Flow

```
DATABASE SCHEMA (PostgreSQL)
    ↓
DatabaseRow (raw types with snake_case)
    ↓
EntityMapper (field transformation)
    ↓
DomainEntity (business types with camelCase)
    ↓
ZodSchema (runtime validation)
    ↓
API Response / Frontend Types
```

---

## Directory Structure

```
packages/shared-library/src/
├── browser.ts                    # Browser-safe exports only
├── server.ts                     # Server exports with Node.js modules
├── index.ts                      # Default export
│
├── types/                        # TypeScript interfaces
│   ├── index.ts                  # Barrel export
│   ├── prompt.ts                 # Domain: Prompt, CreatePromptRequest, etc.
│   ├── job.ts                    # Domain: Job, JobFilter, etc.
│   └── database-rows.ts          # Raw database row interfaces
│
├── validation/                   # Zod schemas
│   ├── index.ts                  # Barrel export
│   ├── prompt.ts                 # PromptSchema, CreatePromptRequestSchema
│   ├── repository.ts             # Filter schemas for queries
│   └── helpers.ts                # validateData(), ValidationError
│
├── constants/                    # Constants and enums
│   ├── enums.ts                  # Enum arrays and derived types
│   └── defaults.ts               # Default values
│
├── repositories/                 # Data access layer
│   ├── base.repository.ts        # Abstract base with CRUD
│   ├── prompts.repository.ts     # Domain-specific repository
│   └── repository-manager.ts     # Singleton registry
│
├── utils/                        # Utility functions
│   ├── entity-mapper.ts          # DB row ↔ entity conversion
│   └── filter-builder.ts         # Query builder for WHERE clauses
│
├── errors/                       # Structured errors
│   ├── base-error.ts             # BaseError class
│   └── application-errors.ts     # ValidationError, NotFoundError, etc.
│
├── database/                     # Database connection (server-only)
│   ├── connection.ts
│   └── transactions.ts
│
└── logging/                      # Logging utilities (server-only)
    └── logger.ts
```

---

## Type Definition Patterns

### Separate Types by Purpose

```typescript
// types/prompt.ts

// 1. Domain Entity - the core business type
export interface Prompt {
  id: string;
  name: string;
  description?: string;
  promptType: PromptType;
  promptTemplate: string;
  arguments: PromptArgument[];
  isArchived: boolean;
  createdAt: Date;
  updatedAt: Date;
}

// 2. Create Request - fields needed to create
export interface CreatePromptRequest {
  name: string;
  description?: string;
  promptType: PromptType;
  promptTemplate: string;
  arguments?: PromptArgument[];
  // Omit: id, isArchived, createdAt, updatedAt (auto-generated)
}

// 3. Update Request - all fields optional for partial updates
export interface UpdatePromptRequest {
  name?: string;
  description?: string;
  promptTemplate?: string;
  arguments?: PromptArgument[];
  isArchived?: boolean;
}

// 4. Filter Type - for query parameters
export interface PromptFilter extends BaseFilter {
  name?: string;
  nameContains?: string;
  isArchived?: boolean;
  createdAfter?: Date;
  createdBefore?: Date;
}
```

### Database Row Types

Keep raw database types separate with explicit snake_case naming:

```typescript
// types/database-rows.ts

export interface PromptsRow {
  id: string;
  name: string;
  description: string | null;      // null, not undefined
  prompt_type: string;              // snake_case column names
  prompt_template: string;
  arguments: any[] | null;          // JSONB columns as any
  is_archived: boolean;
  created_at: Date;                 // pg driver parses dates
  updated_at: Date;
}

export interface ClaudeJobsRow {
  id: string;
  queue_request_id: string;
  status: string;
  started_at: Date;
  completed_at: Date | null;
  error_message: string | null;
}
```

**Why separate row types?**
- Prevents mixing database naming conventions with TypeScript conventions
- Makes the mapping layer explicit and type-safe
- Documents exactly what the database returns

---

## Zod Validation Patterns

### Base Schema with Refinements

```typescript
// validation/prompt.ts
import { z } from 'zod';

// Enum schema from constants
export const PromptTypeSchema = z.enum(['code_review', 'documentation', 'refactor']);

// Nested type schema
export const PromptArgumentSchema = z.object({
  name: z.string().min(1).max(100),
  type: z.enum(['string', 'number', 'boolean', 'select']),
  required: z.boolean().default(true),
  defaultValue: z.string().optional(),
  description: z.string().optional(),
  options: z.array(z.string()).optional(),  // For select type
});

// Main entity schema with business logic
export const PromptSchema = z.object({
  id: z.string().uuid('Invalid prompt ID format'),
  name: z.string().min(1, 'Name required').max(255, 'Name too long'),
  description: z.string().optional(),
  promptType: PromptTypeSchema,
  promptTemplate: z.string().min(1, 'Template required'),
  arguments: z.array(PromptArgumentSchema),
  isArchived: z.boolean(),
  createdAt: z.date(),
  updatedAt: z.date(),
})
  // Business logic validations using refine()
  .refine(
    (data) => {
      // If using select type, options must be provided
      return data.arguments.every(arg =>
        arg.type !== 'select' || (arg.options && arg.options.length > 0)
      );
    },
    { message: 'Select arguments must have options defined' }
  );

// Derive TypeScript type from schema
export type PromptValidated = z.infer<typeof PromptSchema>;
```

### Request Schemas

```typescript
// Create request - subset of fields with defaults
export const CreatePromptRequestSchema = z.object({
  name: z.string().min(1).max(255),
  description: z.string().optional(),
  promptType: PromptTypeSchema,
  promptTemplate: z.string().min(1),
  arguments: z.array(PromptArgumentSchema).default([]),
  isArchived: z.boolean().default(false),
});

// Update request - all optional for partial updates
export const UpdatePromptRequestSchema = z.object({
  name: z.string().min(1).max(255).optional(),
  description: z.string().optional(),
  promptTemplate: z.string().min(1).optional(),
  arguments: z.array(PromptArgumentSchema).optional(),
  isArchived: z.boolean().optional(),
});

// Types derived from schemas
export type CreatePromptRequest = z.infer<typeof CreatePromptRequestSchema>;
export type UpdatePromptRequest = z.infer<typeof UpdatePromptRequestSchema>;
```

### Filter Schemas for Queries

```typescript
// validation/repository.ts

// Base filter for all repositories
export const BaseFilterSchema = z.object({
  limit: z.number().int().positive().max(2000).optional(),
  offset: z.number().int().min(0).optional(),
  orderBy: z.string().optional(),
  orderDirection: z.enum(['ASC', 'DESC']).optional(),
});

// Domain-specific filter extending base
export const PromptFilterSchema = BaseFilterSchema.extend({
  name: z.string().optional(),
  nameContains: z.string().optional(),
  isArchived: z.boolean().optional(),
  promptType: PromptTypeSchema.optional(),
  createdAfter: z.date().optional(),
  createdBefore: z.date().optional(),
});

export type PromptFilter = z.infer<typeof PromptFilterSchema>;
```

### Validation Helpers

```typescript
// validation/helpers.ts

export type ValidationResult<T> =
  | { success: true; data: T }
  | { success: false; errors: z.ZodError };

// Safe validation - returns result object
export function validateData<T>(
  schema: z.ZodSchema<T>,
  data: unknown
): ValidationResult<T> {
  const result = schema.safeParse(data);
  return result.success
    ? { success: true, data: result.data }
    : { success: false, errors: result.error };
}

// Throwing validation - for API boundaries
export function validateInput<T>(
  schema: z.ZodSchema<T>,
  input: unknown
): T {
  const result = validateData(schema, input);
  if (!result.success) {
    throw new ValidationError(
      'Input validation failed',
      result.errors.issues.map(i => `${i.path.join('.')}: ${i.message}`)
    );
  }
  return result.data;
}
```

---

## Repository Patterns

### Abstract Base Repository

```typescript
// repositories/base.repository.ts

export abstract class BaseRepository<
  TEntity,                                    // Domain entity type
  TCreateInput,                               // Create input type
  TUpdateInput,                               // Update input type
  TFilter extends BaseFilter = BaseFilter     // Filter type
> {
  // Required abstract properties
  protected abstract tableName: string;
  protected abstract primaryKey: string;
  protected abstract createSchema: z.ZodSchema<TCreateInput>;
  protected abstract updateSchema: z.ZodSchema<TUpdateInput>;
  protected abstract filterSchema: z.ZodSchema<TFilter>;

  // Required abstract methods
  protected abstract getAllowedFilterColumns(): string[];
  protected abstract getAllowedOrderByColumns(): string[];

  // Optional override points
  protected getEntityMapperConfig?(): EntityMapperConfig;
  protected buildCustomFilter?(
    filter: Partial<TFilter>,
    builder: FilterBuilder
  ): FilterBuilder | null;

  // Standard CRUD operations
  async create(
    input: TCreateInput,
    transaction?: TransactionContext
  ): Promise<TEntity> {
    // 1. Validate input
    const validated = this.validateInput(this.createSchema, input);

    // 2. Map to database columns
    const columns = this.entityMapper.mapCreateInputToColumns(validated);

    // 3. Build and execute INSERT
    const { query, params } = this.buildInsertQuery(columns);
    const result = await this.query(query, params, transaction);

    // 4. Map result back to entity
    return this.mapRowToEntity(result.rows[0]);
  }

  async findById(
    id: string,
    transaction?: TransactionContext
  ): Promise<TEntity | null> {
    const query = `SELECT * FROM ${this.tableName} WHERE ${this.primaryKey} = $1`;
    const result = await this.query(query, [id], transaction);
    return result.rows[0] ? this.mapRowToEntity(result.rows[0]) : null;
  }

  async findMany(
    filter?: Partial<TFilter>,
    transaction?: TransactionContext
  ): Promise<TEntity[]> {
    const { where, params } = this.buildWhereClause(filter);
    const orderBy = this.buildOrderByClause(filter);
    const limit = this.buildLimitClause(filter);

    const query = `SELECT * FROM ${this.tableName} ${where} ${orderBy} ${limit}`;
    const result = await this.query(query, params, transaction);
    return result.rows.map(row => this.mapRowToEntity(row));
  }

  async findManyPaginated(
    filter?: Partial<TFilter>,
    transaction?: TransactionContext
  ): Promise<PaginatedResult<TEntity>> {
    const [data, totalCount] = await Promise.all([
      this.findMany(filter, transaction),
      this.count(filter, transaction),
    ]);

    const limit = filter?.limit ?? 50;
    const offset = filter?.offset ?? 0;

    return {
      data,
      totalCount,
      hasMore: offset + data.length < totalCount,
      offset,
      limit,
    };
  }

  async updateById(
    id: string,
    input: TUpdateInput,
    transaction?: TransactionContext
  ): Promise<TEntity | null> {
    const validated = this.validateInput(this.updateSchema, input);
    const columns = this.entityMapper.mapUpdateInputToColumns(validated);

    if (Object.keys(columns).length === 0) {
      return this.findById(id, transaction);
    }

    const { query, params } = this.buildUpdateQuery(id, columns);
    const result = await this.query(query, params, transaction);
    return result.rows[0] ? this.mapRowToEntity(result.rows[0]) : null;
  }

  async deleteById(
    id: string,
    transaction?: TransactionContext
  ): Promise<boolean> {
    const query = `DELETE FROM ${this.tableName} WHERE ${this.primaryKey} = $1`;
    const result = await this.query(query, [id], transaction);
    return result.rowCount > 0;
  }

  // Transaction support
  async withTransaction<T>(
    operation: (transaction: TransactionContext) => Promise<T>
  ): Promise<T> {
    return runInTransaction(operation);
  }
}

export interface PaginatedResult<T> {
  data: T[];
  totalCount: number;
  hasMore: boolean;
  offset: number;
  limit: number;
}
```

### Concrete Repository Implementation

```typescript
// repositories/prompts.repository.ts

export class PromptsRepository extends BaseRepository<
  Prompt,
  CreatePromptInput,
  UpdatePromptInput,
  PromptFilter
> {
  protected tableName = 'prompts';
  protected primaryKey = 'id';
  protected createSchema = CreatePromptInputSchema;
  protected updateSchema = UpdatePromptInputSchema;
  protected filterSchema = PromptFilterSchema;

  constructor(logger?: Logger) {
    super('PromptsRepository', logger);
  }

  // SQL injection prevention: whitelist columns
  protected getAllowedFilterColumns(): string[] {
    return ['id', 'name', 'prompt_type', 'is_archived', 'created_at'];
  }

  protected getAllowedOrderByColumns(): string[] {
    return ['id', 'name', 'created_at', 'updated_at'];
  }

  // Configure field mapping (see Entity Mapping section)
  protected override getEntityMapperConfig(): EntityMapperConfig {
    return {
      rowToEntity: [
        { source: 'id', target: 'id' },
        { source: 'name', target: 'name' },
        { source: 'prompt_type', target: 'promptType' },
        { source: 'prompt_template', target: 'promptTemplate' },
        {
          source: 'arguments',
          target: 'arguments',
          transform: FieldTransforms.jsonToArray,
          defaultValue: []
        },
        { source: 'is_archived', target: 'isArchived' },
        { source: 'created_at', target: 'createdAt' },
        { source: 'updated_at', target: 'updatedAt' },
        {
          source: 'description',
          target: 'description',
          optional: true
        },
      ],
      createToColumns: [
        { source: 'name', target: 'name' },
        { source: 'promptType', target: 'prompt_type' },
        { source: 'promptTemplate', target: 'prompt_template' },
        {
          source: 'arguments',
          target: 'arguments',
          transform: FieldTransforms.arrayToJson
        },
      ],
      updateToColumns: [
        { source: 'name', target: 'name' },
        { source: 'promptTemplate', target: 'prompt_template' },
        {
          source: 'arguments',
          target: 'arguments',
          transform: FieldTransforms.arrayToJson
        },
        { source: 'isArchived', target: 'is_archived' },
      ],
    };
  }

  // Custom filter building
  protected override buildCustomFilter(
    filter: Partial<PromptFilter>,
    builder: FilterBuilder
  ): FilterBuilder {
    builder
      .addEquals('name', filter.name)
      .addEquals('prompt_type', filter.promptType)
      .addEquals('is_archived', filter.isArchived)
      .addGreaterThanOrEqual('created_at', filter.createdAfter)
      .addLessThanOrEqual('created_at', filter.createdBefore);

    if (filter.nameContains) {
      builder.addContains('name', filter.nameContains);
    }

    return builder;
  }

  // Domain-specific queries
  async findByName(
    name: string,
    transaction?: TransactionContext
  ): Promise<Prompt | null> {
    const query = `SELECT * FROM ${this.tableName} WHERE name = $1`;
    const result = await this.query(query, [name], transaction);
    return result.rows[0] ? this.mapRowToEntity(result.rows[0]) : null;
  }

  async searchByName(
    pattern: string,
    limit = 20
  ): Promise<Prompt[]> {
    const query = `
      SELECT * FROM ${this.tableName}
      WHERE name ILIKE $1
      ORDER BY name ASC
      LIMIT $2
    `;
    const result = await this.query(query, [`%${pattern}%`, limit]);
    return result.rows.map(row => this.mapRowToEntity(row));
  }

  // Complex query with joins
  async getPromptsWithUsageStats(): Promise<Array<Prompt & {
    usageCount: number;
    lastUsed?: Date;
  }>> {
    const query = `
      SELECT
        p.*,
        COALESCE(COUNT(j.id), 0) as usage_count,
        MAX(j.created_at) as last_used
      FROM ${this.tableName} p
      LEFT JOIN claude_jobs j ON j.prompt_id = p.id
      GROUP BY p.id
      ORDER BY usage_count DESC
    `;
    const result = await this.query(query);
    return result.rows.map(row => ({
      ...this.mapRowToEntity(row),
      usageCount: parseInt(row.usage_count) || 0,
      lastUsed: row.last_used || undefined,
    }));
  }

  // Upsert pattern
  async upsert(
    data: Prompt
  ): Promise<{ entity: Prompt; wasCreated: boolean }> {
    const query = `
      INSERT INTO ${this.tableName} (id, name, prompt_type, prompt_template, arguments)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        prompt_type = EXCLUDED.prompt_type,
        prompt_template = EXCLUDED.prompt_template,
        arguments = EXCLUDED.arguments,
        updated_at = NOW()
      RETURNING *, (xmax = 0) AS was_created
    `;
    const result = await this.query(query, [
      data.id,
      data.name,
      data.promptType,
      data.promptTemplate,
      JSON.stringify(data.arguments),
    ]);
    return {
      entity: this.mapRowToEntity(result.rows[0]),
      wasCreated: result.rows[0].was_created,
    };
  }
}
```

---

## Entity Mapping

### EntityMapper Configuration

```typescript
// utils/entity-mapper.ts

export interface FieldMapping {
  source: string;                    // Source field name
  target: string;                    // Target field name
  transform?: (value: any) => any;   // Optional transformation
  optional?: boolean;                // Skip if null/undefined
  includeIfValue?: boolean;          // Only include if truthy
  defaultValue?: any;                // Default if undefined
}

export interface EntityMapperConfig {
  rowToEntity: FieldMapping[];       // Database → Domain
  createToColumns: FieldMapping[];   // CreateInput → Database
  updateToColumns: FieldMapping[];   // UpdateInput → Database
}

export class EntityMapper<TRow, TEntity, TCreateInput, TUpdateInput> {
  constructor(private config: EntityMapperConfig) {}

  mapRowToEntity(row: TRow): TEntity {
    const entity: Record<string, any> = {};

    for (const mapping of this.config.rowToEntity) {
      let value = (row as any)[mapping.source];

      // Apply default value
      if (value === undefined || value === null) {
        if (mapping.defaultValue !== undefined) {
          value = mapping.defaultValue;
        } else if (mapping.optional) {
          continue;  // Skip optional null fields
        }
      }

      // Apply transformation
      if (mapping.transform && value !== null) {
        value = mapping.transform(value);
      }

      // Include based on conditions
      if (mapping.includeIfValue && !value) {
        continue;
      }

      entity[mapping.target] = value;
    }

    return entity as TEntity;
  }

  mapCreateInputToColumns(input: TCreateInput): Record<string, any> {
    return this.mapFields(input, this.config.createToColumns);
  }

  mapUpdateInputToColumns(input: TUpdateInput): Record<string, any> {
    const result: Record<string, any> = {};

    for (const mapping of this.config.updateToColumns) {
      const value = (input as any)[mapping.source];

      // Only include fields that are explicitly set (not undefined)
      if (value !== undefined) {
        result[mapping.target] = mapping.transform
          ? mapping.transform(value)
          : value;
      }
    }

    return result;
  }

  private mapFields(
    source: any,
    mappings: FieldMapping[]
  ): Record<string, any> {
    const result: Record<string, any> = {};

    for (const mapping of mappings) {
      let value = source[mapping.source];

      if (value === undefined && mapping.defaultValue !== undefined) {
        value = mapping.defaultValue;
      }

      if (mapping.transform && value !== undefined) {
        value = mapping.transform(value);
      }

      result[mapping.target] = value;
    }

    return result;
  }
}
```

### Common Field Transforms

```typescript
// utils/entity-mapper.ts

export const FieldTransforms = {
  // JSON array handling
  arrayToJson: (value: any[]): string | null =>
    value ? JSON.stringify(value) : null,

  jsonToArray: (value: string | any[] | null): any[] => {
    if (!value) return [];
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') {
      try {
        const parsed = JSON.parse(value);
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    }
    return [];
  },

  // JSON object handling
  objectToJson: (value: Record<string, any>): string | null =>
    value ? JSON.stringify(value) : null,

  jsonToObject: (value: string | object | null): Record<string, any> | undefined => {
    if (!value) return undefined;
    if (typeof value === 'object' && !Array.isArray(value)) return value;
    if (typeof value === 'string') {
      try {
        const parsed = JSON.parse(value);
        return typeof parsed === 'object' && !Array.isArray(parsed)
          ? parsed
          : undefined;
      } catch {
        return undefined;
      }
    }
    return undefined;
  },

  // Date handling
  toDate: (value: any): Date =>
    value ? new Date(value) : new Date(),

  toIsoString: (value: Date): string =>
    value.toISOString(),

  // Naming convention conversion
  snakeToCamel: (value: string): string =>
    value.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase()),

  camelToSnake: (value: string): string =>
    value.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`),

  // Boolean coercion
  toBoolean: (value: any): boolean =>
    value === true || value === 'true' || value === 1,
};
```

---

## Query Building

### FilterBuilder Pattern

```typescript
// utils/filter-builder.ts

export class FilterBuilder {
  private conditions: string[] = [];
  private params: any[] = [];
  private paramIndex = 1;

  // Equality
  addEquals(field: string, value: any): this {
    if (value !== undefined && value !== null) {
      this.conditions.push(`${field} = $${this.paramIndex}`);
      this.params.push(value);
      this.paramIndex++;
    }
    return this;
  }

  // Not equal
  addNotEquals(field: string, value: any): this {
    if (value !== undefined && value !== null) {
      this.conditions.push(`${field} != $${this.paramIndex}`);
      this.params.push(value);
      this.paramIndex++;
    }
    return this;
  }

  // Pattern matching (ILIKE)
  addContains(field: string, pattern: string): this {
    if (pattern) {
      this.conditions.push(`${field} ILIKE $${this.paramIndex}`);
      this.params.push(`%${pattern}%`);
      this.paramIndex++;
    }
    return this;
  }

  addStartsWith(field: string, pattern: string): this {
    if (pattern) {
      this.conditions.push(`${field} ILIKE $${this.paramIndex}`);
      this.params.push(`${pattern}%`);
      this.paramIndex++;
    }
    return this;
  }

  // Comparisons
  addGreaterThan(field: string, value: any): this {
    if (value !== undefined && value !== null) {
      this.conditions.push(`${field} > $${this.paramIndex}`);
      this.params.push(value);
      this.paramIndex++;
    }
    return this;
  }

  addGreaterThanOrEqual(field: string, value: any): this {
    if (value !== undefined && value !== null) {
      this.conditions.push(`${field} >= $${this.paramIndex}`);
      this.params.push(value);
      this.paramIndex++;
    }
    return this;
  }

  addLessThan(field: string, value: any): this {
    if (value !== undefined && value !== null) {
      this.conditions.push(`${field} < $${this.paramIndex}`);
      this.params.push(value);
      this.paramIndex++;
    }
    return this;
  }

  addLessThanOrEqual(field: string, value: any): this {
    if (value !== undefined && value !== null) {
      this.conditions.push(`${field} <= $${this.paramIndex}`);
      this.params.push(value);
      this.paramIndex++;
    }
    return this;
  }

  // IN clause
  addIn(field: string, values: any[]): this {
    if (values && values.length > 0) {
      const placeholders = values
        .map(() => `$${this.paramIndex++}`)
        .join(', ');
      this.conditions.push(`${field} IN (${placeholders})`);
      this.params.push(...values);
    }
    return this;
  }

  // NULL checks
  addIsNull(field: string): this {
    this.conditions.push(`${field} IS NULL`);
    return this;
  }

  addIsNotNull(field: string): this {
    this.conditions.push(`${field} IS NOT NULL`);
    return this;
  }

  // Date range
  addDateRange(field: string, start?: Date, end?: Date): this {
    if (start) {
      this.addGreaterThanOrEqual(field, start);
    }
    if (end) {
      this.addLessThanOrEqual(field, end);
    }
    return this;
  }

  // Build final clause
  build(): { where: string; params: any[] } {
    return {
      where: this.conditions.length > 0
        ? `WHERE ${this.conditions.join(' AND ')}`
        : '',
      params: this.params,
    };
  }

  // For debugging
  toDebugString(): string {
    const { where, params } = this.build();
    return `${where} -- params: ${JSON.stringify(params)}`;
  }
}
```

### Usage in Repository

```typescript
protected override buildCustomFilter(
  filter: Partial<PromptFilter>,
  builder: FilterBuilder
): FilterBuilder {
  return builder
    .addEquals('name', filter.name)
    .addEquals('is_archived', filter.isArchived)
    .addContains('name', filter.nameContains)
    .addIn('prompt_type', filter.promptTypes)
    .addDateRange('created_at', filter.createdAfter, filter.createdBefore);
}
```

---

## Browser/Server Split Architecture

### Browser Bundle (No Node.js)

```typescript
// browser.ts

// Types - pure TypeScript interfaces
export * from './types/index.js';

// Validation - Zod is browser-safe
export * from './validation/index.js';

// Constants - pure data
export * from './constants/index.js';

// Errors - no Node.js dependencies
export * from './errors/base-error.js';
export * from './errors/application-errors.js';

// NOT exported:
// - logging/* (pino, fs, os)
// - database/* (pg)
// - repositories/* (pg)
// - utils with Buffer
```

### Server Bundle (Full)

```typescript
// server.ts

// Everything from browser
export * from './types/index.js';
export * from './validation/index.js';
export * from './constants/index.js';
export * from './errors/index.js';

// Plus server-only modules
export * from './database/index.js';      // pg connections
export * from './repositories/index.js';  // data access
export * from './logging/index.js';       // pino logger
export * from './utils/index.js';         // all utilities
export * from './services/index.js';      // business logic
```

### Package.json Exports

```json
{
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    },
    "./browser": {
      "types": "./dist/browser.d.ts",
      "import": "./dist/browser.js"
    },
    "./server": {
      "types": "./dist/server.d.ts",
      "import": "./dist/server.js"
    }
  }
}
```

### Import Patterns

```typescript
// Frontend (React, Vite)
import {
  Prompt,
  PromptSchema,
  ValidationError
} from '@myorg/shared-library/browser';

// Backend (Express, Node.js)
import {
  createLogger,
  RepositoryManager,
  Prompt,
  PromptSchema
} from '@myorg/shared-library/server';
```

---

## Error Handling

### Error Hierarchy

```typescript
// errors/base-error.ts

export abstract class BaseError extends Error {
  readonly code: string;
  readonly statusCode: number;
  readonly isClientError: boolean;
  readonly context?: Record<string, any>;
  readonly cause?: Error;

  constructor(
    message: string,
    code: string,
    statusCode: number,
    isClientError: boolean,
    context?: Record<string, any>,
    cause?: Error
  ) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.statusCode = statusCode;
    this.isClientError = isClientError;
    this.context = context;
    this.cause = cause;
    Error.captureStackTrace(this, this.constructor);
  }

  // Override for user-facing messages (hide internal details)
  getUserMessage(): string {
    return this.message;
  }

  toJSON(): Record<string, any> {
    return {
      name: this.name,
      message: this.message,
      code: this.code,
      statusCode: this.statusCode,
      context: this.context,
    };
  }
}
```

### Specific Error Types

```typescript
// errors/application-errors.ts

export class ValidationError extends BaseError {
  readonly validationErrors: string[];

  constructor(message: string, errors: string[] | z.ZodError = []) {
    const errorStrings = errors instanceof z.ZodError
      ? errors.issues.map(i => `${i.path.join('.')}: ${i.message}`)
      : errors;

    super(message, 'VALIDATION_ERROR', 400, true, { errors: errorStrings });
    this.validationErrors = errorStrings;
  }

  override getUserMessage(): string {
    return this.validationErrors.length > 0
      ? `Validation failed: ${this.validationErrors.join('; ')}`
      : this.message;
  }
}

export class NotFoundError extends BaseError {
  readonly resource: string;
  readonly resourceId?: string;

  constructor(resource: string, resourceId?: string, message?: string) {
    const defaultMessage = resourceId
      ? `${resource} with ID '${resourceId}' not found`
      : `${resource} not found`;

    super(message || defaultMessage, 'NOT_FOUND', 404, true, {
      resource,
      resourceId,
    });
    this.resource = resource;
    this.resourceId = resourceId;
  }
}

export class ConflictError extends BaseError {
  constructor(message: string, context?: Record<string, any>) {
    super(message, 'CONFLICT', 409, true, context);
  }
}

export class AuthenticationError extends BaseError {
  constructor(message = 'Authentication required') {
    super(message, 'AUTHENTICATION_ERROR', 401, true);
  }

  override getUserMessage(): string {
    return 'Authentication required';  // Never leak details
  }
}

export class AuthorizationError extends BaseError {
  constructor(message = 'Access denied') {
    super(message, 'AUTHORIZATION_ERROR', 403, true);
  }
}

export class DatabaseError extends BaseError {
  constructor(
    message: string,
    context?: Record<string, any>,
    cause?: Error
  ) {
    super(message, 'DATABASE_ERROR', 500, false, context, cause);
  }
}

export class DatabaseQueryError extends DatabaseError {
  constructor(
    message: string,
    query?: string,
    params?: any[],
    cause?: Error
  ) {
    super(message, { query, paramCount: params?.length }, cause);
  }
}
```

---

## Constants and Enums

### Enum Pattern

```typescript
// constants/enums.ts

// Define as const arrays (source of truth)
export const PROMPT_TYPES = [
  'code_review',
  'documentation',
  'refactor',
  'testing',
] as const;

export const JOB_STATUSES = [
  'pending',
  'running',
  'completed',
  'failed',
  'cancelled',
] as const;

export const ORDER_DIRECTIONS = ['ASC', 'DESC'] as const;

// Derive TypeScript types
export type PromptType = (typeof PROMPT_TYPES)[number];
export type JobStatus = (typeof JOB_STATUSES)[number];
export type OrderDirection = (typeof ORDER_DIRECTIONS)[number];

// Create Zod schemas from the same source
export const PromptTypeSchema = z.enum(PROMPT_TYPES);
export const JobStatusSchema = z.enum(JOB_STATUSES);
export const OrderDirectionSchema = z.enum(ORDER_DIRECTIONS);
```

**Benefits:**
- Single source of truth
- TypeScript types automatically synced
- Zod schemas use same values
- Easy to add new values

---

## Best Practices Summary

### Type Safety

1. **Separate concerns**: Database rows, domain entities, and API DTOs should be distinct types
2. **Derive from schemas**: Use `z.infer<typeof Schema>` for compile-time + runtime safety
3. **Explicit mappings**: Define clear transformation between layers
4. **Strict TypeScript**: Enable all strict compiler options

### Repository Design

1. **Generic base class**: Reuse CRUD logic across repositories
2. **Whitelist columns**: Prevent SQL injection by explicitly allowing filter/sort columns
3. **Transaction support**: Pass transaction context through all operations
4. **Parameterized queries**: Never interpolate user input into SQL strings

### Validation

1. **Validate at boundaries**: API entry points, repository inputs
2. **Business logic in refinements**: Use `.refine()` for cross-field validation
3. **Detailed error messages**: Include field paths and specific errors
4. **Structured error types**: Use custom error classes with codes and context

### Code Organization

1. **One file per domain**: Keep related types, schemas, and repos together
2. **Barrel exports**: Use index.ts for clean imports
3. **Split browser/server**: Explicitly separate Node.js dependencies
4. **Centralized access**: Use RepositoryManager for consistent initialization

### Database Patterns

1. **UTC everywhere**: Store all timestamps in UTC
2. **JSONB for arrays/objects**: Use PostgreSQL JSONB with proper typing
3. **Explicit null handling**: Database null vs TypeScript undefined
4. **Migration-driven schema**: Use migration files, never drop schema

---

## Quick Reference

| Layer | Naming | Example |
|-------|--------|---------|
| Database Column | snake_case | `prompt_type` |
| Database Row Type | PascalCase + Row | `PromptsRow` |
| Domain Entity | PascalCase | `Prompt` |
| Create Input | Create + Domain | `CreatePromptRequest` |
| Update Input | Update + Domain | `UpdatePromptRequest` |
| Filter Type | Domain + Filter | `PromptFilter` |
| Zod Schema | Domain + Schema | `PromptSchema` |
| Repository | Domain + Repository | `PromptsRepository` |

---

## Key Files Reference

| Purpose | File Pattern |
|---------|--------------|
| Domain types | `types/{domain}.ts` |
| Database rows | `types/database-rows.ts` |
| Validation schemas | `validation/{domain}.ts` |
| Repository filter schemas | `validation/repository.ts` |
| Repository implementation | `repositories/{domain}.repository.ts` |
| Entity mapping | `utils/entity-mapper.ts` |
| Query building | `utils/filter-builder.ts` |
| Error types | `errors/application-errors.ts` |
| Enum constants | `constants/enums.ts` |
| Browser exports | `browser.ts` |
| Server exports | `server.ts` |
