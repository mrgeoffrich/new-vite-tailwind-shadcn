# Shared Package - Data Access Patterns

Patterns for database access, from simple direct ORM to full repository pattern.

---

## Approach 1: Direct ORM (Simple Projects)

Best for simple CRUD apps with Prisma or similar ORM.

```typescript
// controllers/product.controller.ts
import { prisma } from '../config/database';
import { Request, Response } from 'express';

export class ProductController {
  async list(req: Request, res: Response) {
    const { page = 1, limit = 20 } = req.query as { page?: number; limit?: number };
    const skip = (page - 1) * limit;

    const [products, totalCount] = await Promise.all([
      prisma.product.findMany({
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.product.count(),
    ]);

    res.json({
      success: true,
      data: products,
      pagination: {
        page,
        limit,
        totalCount,
        totalPages: Math.ceil(totalCount / limit),
        hasMore: skip + products.length < totalCount,
      },
    });
  }

  async create(req: Request, res: Response) {
    // req.body already validated by middleware
    const product = await prisma.product.create({
      data: req.body,
    });
    res.status(201).json({ success: true, data: product });
  }

  async getById(req: Request, res: Response) {
    const product = await prisma.product.findUnique({
      where: { id: req.params.id },
    });

    if (!product) {
      throw new NotFoundError('Product', req.params.id);
    }

    res.json({ success: true, data: product });
  }
}
```

---

## Approach 2: Service Layer (Medium Projects)

Add a service layer for business logic while keeping ORM access simple.

```typescript
// services/product.service.ts
import { prisma } from '../config/database';
import { CreateProductRequest, UpdateProductRequest, ProductFilter } from '@your-org/shared';
import { NotFoundError, ConflictError } from '@your-org/shared';

export class ProductService {
  async create(data: CreateProductRequest) {
    // Business logic: check for duplicate name
    const existing = await prisma.product.findFirst({
      where: { name: data.name },
    });
    if (existing) {
      throw new ConflictError(`Product with name '${data.name}' already exists`);
    }

    return prisma.product.create({ data });
  }

  async update(id: string, data: UpdateProductRequest) {
    const product = await prisma.product.findUnique({ where: { id } });
    if (!product) {
      throw new NotFoundError('Product', id);
    }

    // Business logic: name uniqueness check if name is changing
    if (data.name && data.name !== product.name) {
      const existing = await prisma.product.findFirst({
        where: { name: data.name, NOT: { id } },
      });
      if (existing) {
        throw new ConflictError(`Product with name '${data.name}' already exists`);
      }
    }

    return prisma.product.update({
      where: { id },
      data,
    });
  }

  async findMany(filter: ProductFilter) {
    const { limit = 20, offset = 0, orderBy, orderDirection, ...where } = filter;

    const whereClause: any = {};
    if (where.name) whereClause.name = where.name;
    if (where.nameContains) whereClause.name = { contains: where.nameContains, mode: 'insensitive' };
    if (where.category) whereClause.category = where.category;
    if (where.isActive !== undefined) whereClause.isActive = where.isActive;
    if (where.minPrice || where.maxPrice) {
      whereClause.price = {};
      if (where.minPrice) whereClause.price.gte = where.minPrice;
      if (where.maxPrice) whereClause.price.lte = where.maxPrice;
    }

    return prisma.product.findMany({
      where: whereClause,
      skip: offset,
      take: limit,
      orderBy: orderBy ? { [orderBy]: orderDirection || 'desc' } : undefined,
    });
  }
}
```

---

## Approach 3: Repository Pattern (Complex Projects)

Full abstraction for complex apps with raw SQL or multiple database types.

```typescript
// repositories/base.repository.ts

export interface PaginatedResult<T> {
  data: T[];
  totalCount: number;
  hasMore: boolean;
}

export abstract class BaseRepository<TEntity, TCreateInput, TUpdateInput, TFilter> {
  protected abstract tableName: string;
  protected abstract primaryKey: string;

  // Subclasses implement entity-specific mapping
  protected abstract mapRowToEntity(row: any): TEntity;
  protected abstract mapCreateInputToColumns(input: TCreateInput): Record<string, any>;
  protected abstract mapUpdateInputToColumns(input: TUpdateInput): Record<string, any>;
  protected abstract buildWhereClause(filter: Partial<TFilter>): { sql: string; params: any[] };

  // Whitelist columns for security
  protected abstract getAllowedOrderByColumns(): string[];

  async findById(id: string): Promise<TEntity | null> {
    const result = await this.query(
      `SELECT * FROM ${this.tableName} WHERE ${this.primaryKey} = $1`,
      [id]
    );
    return result.rows[0] ? this.mapRowToEntity(result.rows[0]) : null;
  }

  async findMany(filter: Partial<TFilter> & { limit?: number; offset?: number }): Promise<TEntity[]> {
    const { sql: whereSql, params } = this.buildWhereClause(filter);
    const orderBy = this.buildOrderByClause(filter);
    const limitOffset = this.buildLimitClause(filter);

    const query = `SELECT * FROM ${this.tableName} ${whereSql} ${orderBy} ${limitOffset}`;
    const result = await this.query(query, params);
    return result.rows.map((row) => this.mapRowToEntity(row));
  }

  async create(input: TCreateInput): Promise<TEntity> {
    const columns = this.mapCreateInputToColumns(input);
    const keys = Object.keys(columns);
    const values = Object.values(columns);
    const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');

    const query = `
      INSERT INTO ${this.tableName} (${keys.join(', ')})
      VALUES (${placeholders})
      RETURNING *
    `;
    const result = await this.query(query, values);
    return this.mapRowToEntity(result.rows[0]);
  }

  async updateById(id: string, input: TUpdateInput): Promise<TEntity | null> {
    const columns = this.mapUpdateInputToColumns(input);
    if (Object.keys(columns).length === 0) {
      return this.findById(id);
    }

    const sets = Object.keys(columns).map((key, i) => `${key} = $${i + 2}`);
    const values = [id, ...Object.values(columns)];

    const query = `
      UPDATE ${this.tableName}
      SET ${sets.join(', ')}, updated_at = NOW()
      WHERE ${this.primaryKey} = $1
      RETURNING *
    `;
    const result = await this.query(query, values);
    return result.rows[0] ? this.mapRowToEntity(result.rows[0]) : null;
  }

  async deleteById(id: string): Promise<boolean> {
    const result = await this.query(
      `DELETE FROM ${this.tableName} WHERE ${this.primaryKey} = $1`,
      [id]
    );
    return result.rowCount > 0;
  }

  protected buildOrderByClause(filter: any): string {
    const { orderBy, orderDirection = 'DESC' } = filter;
    if (!orderBy) return 'ORDER BY created_at DESC';

    const allowed = this.getAllowedOrderByColumns();
    if (!allowed.includes(orderBy)) {
      return 'ORDER BY created_at DESC';
    }

    const direction = orderDirection.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
    return `ORDER BY ${orderBy} ${direction}`;
  }

  protected buildLimitClause(filter: any): string {
    const limit = Math.min(filter.limit || 50, 2000);
    const offset = filter.offset || 0;
    return `LIMIT ${limit} OFFSET ${offset}`;
  }

  protected abstract query(sql: string, params?: any[]): Promise<{ rows: any[]; rowCount: number }>;
}
```

---

## Entity Mapping (When Needed)

For transforming database rows to domain entities:

```typescript
// utils/entity-mapper.ts

export interface FieldMapping {
  source: string;                    // Source field name
  target: string;                    // Target field name
  transform?: (value: any) => any;   // Optional transformation
  optional?: boolean;                // Skip if null/undefined
  defaultValue?: any;                // Default if null/undefined
}

export const FieldTransforms = {
  // JSON handling
  jsonToArray: (value: any): any[] => {
    if (!value) return [];
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') {
      try {
        return JSON.parse(value);
      } catch {
        return [];
      }
    }
    return [];
  },

  arrayToJson: (value: any[]): string | null =>
    value ? JSON.stringify(value) : null,

  // Boolean coercion
  toBoolean: (value: any): boolean =>
    value === true || value === 'true' || value === 1,

  // Naming conventions
  snakeToCamel: (value: string): string =>
    value.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase()),
};

// Simple mapping function (alternative to full EntityMapper class)
export function mapRow<T>(row: any, mappings: FieldMapping[]): T {
  const result: Record<string, any> = {};

  for (const mapping of mappings) {
    let value = row[mapping.source];

    if (value === null || value === undefined) {
      if (mapping.defaultValue !== undefined) {
        value = mapping.defaultValue;
      } else if (mapping.optional) {
        continue;
      }
    }

    if (mapping.transform && value != null) {
      value = mapping.transform(value);
    }

    result[mapping.target] = value;
  }

  return result as T;
}
```
