import { Hono } from 'hono';
import { and, eq, like } from 'drizzle-orm';
import { db } from '../services/db.js';
import { customers } from '../schema.js';
import { hasBusinessPermission } from '../services/access.js';
import type { AppEnv } from '../middleware/auth.js';

export const customerRoutes = new Hono<AppEnv>();
customerRoutes.get('/', async (c) => {
  const businessId = c.req.query('business_id');
  if (!businessId) return c.json({ error: 'BUSINESS_REQUIRED' }, 400);
  if (!await hasBusinessPermission(c.get('userId'), businessId, 'customers.read')) return c.json({ error: 'FORBIDDEN' }, 403);
  const q = c.req.query('q') ?? '';
  const rows = await db.select().from(customers).where(and(eq(customers.businessId,businessId),like(customers.name,'%'+q+'%'))).limit(500);
  return c.json({ data: rows.map(r => ({ id:r.id, business_id:r.businessId, name:r.name, phone:r.phone, email:r.email, address:r.address, notes:r.notes, balance_due:r.balanceDue, created_at:r.createdAt, updated_at:r.updatedAt })) });
});
