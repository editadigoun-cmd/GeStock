import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, sql, desc } from 'drizzle-orm';
import { db } from '../services/db.js';
import { hasBusinessPermission } from '../services/access.js';
import { products, warehouses, stockLevels, stockMovements } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';

export const stockRoutes = new Hono<AppEnv>();
const movementSchema = z.object({
  business_id: z.string().uuid(), warehouse_id: z.string().uuid(), product_id: z.string().uuid(),
  movement_type: z.enum(['opening', 'purchase', 'sale', 'return_in', 'return_out', 'adjustment', 'transfer_in', 'transfer_out']),
  quantity_delta: z.number().finite().refine((v) => v !== 0), unit_cost: z.number().nonnegative().optional(), note: z.string().max(500).optional(),
});
stockRoutes.post('/movements', async (c) => {
  const parsed = movementSchema.safeParse(await c.req.json());
  if (!parsed.success) return c.json({ error: 'VALIDATION_ERROR', details: parsed.error.flatten() }, 422);
  const input = parsed.data;
  if (!await hasBusinessPermission(c.get('userId'), input.business_id, 'stock.write')) return c.json({ error: 'FORBIDDEN' }, 403);
  const [product] = await db.select({ id: products.id }).from(products).where(and(eq(products.id, input.product_id), eq(products.businessId, input.business_id))).limit(1);
  const [warehouse] = await db.select({ id: warehouses.id }).from(warehouses).where(and(eq(warehouses.id, input.warehouse_id), eq(warehouses.businessId, input.business_id))).limit(1);
  if (!product || !warehouse) return c.json({ error: 'PRODUCT_OR_WAREHOUSE_NOT_FOUND' }, 404);
  const now = new Date().toISOString(), movementId = crypto.randomUUID();
  await db.batch([
    db.insert(stockMovements).values({ id: movementId, businessId: input.business_id, warehouseId: input.warehouse_id, productId: input.product_id, movementType: input.movement_type, quantityDelta: input.quantity_delta, unitCost: input.unit_cost ?? null, note: input.note ?? null, occurredAt: now, createdAt: now }),
    db.insert(stockLevels).values({ id: crypto.randomUUID(), businessId: input.business_id, warehouseId: input.warehouse_id, productId: input.product_id, quantity: input.quantity_delta, updatedAt: now }).onConflictDoUpdate({ target: [stockLevels.warehouseId, stockLevels.productId], set: { quantity: sql`${stockLevels.quantity} + ${input.quantity_delta}`, updatedAt: now } }),
  ]);
  const [movement] = await db.select().from(stockMovements).where(eq(stockMovements.id, movementId)).limit(1);
  return c.json({ data: movement }, 201);
});
stockRoutes.get('/levels', async (c) => {
  const businessId = c.req.query('business_id');
  if (!businessId) return c.json({ error: 'BUSINESS_REQUIRED' }, 400);
  if (!await hasBusinessPermission(c.get('userId'), businessId, 'stock.read')) return c.json({ error: 'FORBIDDEN' }, 403);
  return c.json({ data: await db.select().from(stockLevels).where(eq(stockLevels.businessId, businessId)) });
});
stockRoutes.get('/movements', async (c) => {
  const businessId = c.req.query('business_id');
  if (!businessId) return c.json({ error: 'BUSINESS_REQUIRED' }, 400);
  if (!await hasBusinessPermission(c.get('userId'), businessId, 'stock.read')) return c.json({ error: 'FORBIDDEN' }, 403);
  const productId = c.req.query('product_id');
  const rows = await db.select({ id: stockMovements.id, business_id: stockMovements.businessId, warehouse_id: stockMovements.warehouseId, product_id: stockMovements.productId, product_name: products.name, movement_type: stockMovements.movementType, quantity_delta: stockMovements.quantityDelta, note: stockMovements.note, occurred_at: stockMovements.occurredAt })
    .from(stockMovements).leftJoin(products, eq(products.id, stockMovements.productId))
    .where(productId ? and(eq(stockMovements.businessId, businessId), eq(stockMovements.productId, productId)) : eq(stockMovements.businessId, businessId))
    .orderBy(desc(stockMovements.occurredAt)).limit(100);
  return c.json({ data: rows });
});
