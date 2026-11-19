import { Hono } from 'hono';
import { and, desc, eq } from 'drizzle-orm';
import { db } from '../services/db.js';
import { appUsers, sales, saleItems, salePayments } from '../schema.js';
import { hasBusinessAccess } from '../services/access.js';
import { createSaleTransaction, saleInputSchema } from '../services/sales.js';
import type { AppEnv } from '../middleware/auth.js';

export const salesRoutes = new Hono<AppEnv>();

salesRoutes.get('/', async (c) => {
  const businessId = c.req.query('business_id');
  if (!businessId) return c.json({ error: 'BUSINESS_REQUIRED' }, 400);
  if (!await hasBusinessAccess(c.get('userId'), businessId)) return c.json({ error: 'FORBIDDEN' }, 403);
  const rows = await db.select().from(sales).where(eq(sales.businessId, businessId)).orderBy(desc(sales.soldAt)).limit(100);
  return c.json({ data: rows });
});

salesRoutes.get('/:id', async (c) => {
  const businessId = c.req.query('business_id');
  const id = c.req.param('id');
  if (!businessId) return c.json({ error: 'BUSINESS_REQUIRED' }, 400);
  if (!await hasBusinessAccess(c.get('userId'), businessId)) return c.json({ error: 'FORBIDDEN' }, 403);
  const [sale] = await db.select().from(sales).where(and(eq(sales.id, id), eq(sales.businessId, businessId))).limit(1);
  if (!sale) return c.json({ error: 'SALE_NOT_FOUND' }, 404);
  const items = await db.select().from(saleItems).where(eq(saleItems.saleId, id));
  const payments = await db.select().from(salePayments).where(eq(salePayments.saleId, id));
  return c.json({ data: { ...sale, items, payments } });
});

salesRoutes.post('/', async (c) => {
  const parsed = saleInputSchema.safeParse(await c.req.json());
  if (!parsed.success) return c.json({ error: 'VALIDATION_ERROR', details: parsed.error.flatten() }, 422);
  const input = parsed.data;
  if (!await hasBusinessAccess(c.get('userId'), input.business_id)) return c.json({ error: 'FORBIDDEN' }, 403);
  const [user] = await db.select({ id: appUsers.id }).from(appUsers).where(eq(appUsers.authSubject, c.get('userId'))).limit(1);
  if (!user) return c.json({ error: 'USER_NOT_FOUND' }, 401);
  try {
    const result = await createSaleTransaction(user.id, input);
    return c.json({ data: result }, result.duplicate ? 200 : 201);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'SALE_FAILED';
    if (message.startsWith('INSUFFICIENT_STOCK:')) return c.json({ error: 'INSUFFICIENT_STOCK', product: message.split(':').slice(1).join(':') }, 409);
    if (message === 'PAYMENT_INCOMPLETE' || message === 'PAYMENT_AMOUNT_MISMATCH') return c.json({ error: message }, 422);
    if (message.endsWith('_NOT_FOUND') || message === 'PRODUCT_INACTIVE' || message === 'SALE_NUMBER_EXISTS') return c.json({ error: message }, 409);
    return c.json({ error: 'SALE_FAILED' }, 409);
  }
});
