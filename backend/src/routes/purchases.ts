import { Hono } from 'hono';
import { and, eq } from 'drizzle-orm';
import { db } from '../services/db.js';
import { purchases, purchaseItems } from '../schema.js';
import { hasBusinessAccess } from '../services/access.js';
import type { AppEnv } from '../middleware/auth.js';

export const purchaseRoutes = new Hono<AppEnv>();
purchaseRoutes.get('/', async (c) => {
  const businessId = c.req.query('business_id');
  if (!businessId) return c.json({ error: 'BUSINESS_REQUIRED' }, 400);
  if (!await hasBusinessAccess(c.get('userId'), businessId)) return c.json({ error: 'FORBIDDEN' }, 403);
  const rows = await db.select().from(purchases).where(eq(purchases.businessId, businessId)).orderBy(purchases.createdAt);
  const data = [];
  for (const row of rows) {
    const items = await db.select().from(purchaseItems).where(eq(purchaseItems.purchaseId, row.id));
    data.push({ id: row.id, business_id: row.businessId, supplier_id: row.supplierId, warehouse_id: row.warehouseId,
      purchase_number: row.purchaseNumber, status: row.status, currency_code: row.currencyCode, total: row.total,
      ordered_at: row.orderedAt, received_at: row.receivedAt, created_at: row.createdAt,
      items: items.map(i => ({ id: i.id, product_id: i.productId, product_name_snapshot: i.productNameSnapshot, quantity: i.quantity, unit_cost: i.unitCost, line_total: i.lineTotal })) });
  }
  return c.json({ data });
});
