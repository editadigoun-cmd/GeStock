import { Hono } from 'hono';
import { sql, eq, desc } from 'drizzle-orm';
import { db } from '../services/db.js';
import { appUsers, businesses, products, sales, stockMovements, syncOperations, businessMemberships } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';
import type { Context } from 'hono';

export const adminRoutes = new Hono<AppEnv>();

function isAdmin(c: Context<AppEnv>): boolean {
  const configured = c.env.ADMIN_EMAIL?.trim().toLowerCase();
  return Boolean(configured && c.get('emailVerified') && c.get('email')?.toLowerCase() === configured);
}
adminRoutes.use('*', async (c, next) => {
  if (!isAdmin(c)) return c.json({ error: 'ADMIN_REQUIRED' }, 403);
  await next();
});

adminRoutes.get('/overview', async (c) => {
  const [users] = await db.select({ count: sql<number>`count(*)` }).from(appUsers);
  const [businessCount] = await db.select({ count: sql<number>`count(*)` }).from(businesses);
  const [productCount] = await db.select({ count: sql<number>`count(*)` }).from(products);
  const [saleCount] = await db.select({ count: sql<number>`count(*)` }).from(sales);
  const [movementCount] = await db.select({ count: sql<number>`count(*)` }).from(stockMovements);
  const [pending] = await db.select({ count: sql<number>`count(*)` }).from(syncOperations).where(eq(syncOperations.status, 'queued'));
  const [conflicts] = await db.select({ count: sql<number>`count(*)` }).from(syncOperations).where(eq(syncOperations.status, 'conflict'));
  const revenueByCurrency = await db.select({ currency_code: sales.currencyCode, total: sql<number>`COALESCE(SUM(${sales.total}), 0)` }).from(sales).where(eq(sales.status, 'completed')).groupBy(sales.currencyCode);
  const [active] = await db.select({ count: sql<number>`count(*)` }).from(businesses).where(eq(businesses.status, 'active'));
  return c.json({ data: {
    users: users.count, businesses: businessCount.count, active_businesses: active.count,
    products: productCount.count, sales: saleCount.count, stock_movements: movementCount.count,
    revenue_by_currency: revenueByCurrency, sync_pending: pending.count, sync_conflicts: conflicts.count,
  } });
});

adminRoutes.get('/businesses', async (c) => {
  const rows = await db.select({
    id: businesses.id, name: businesses.name, business_type: businesses.businessType,
    country_code: businesses.countryCode, currency_code: businesses.currencyCode,
    status: businesses.status, created_at: businesses.createdAt,
    members: sql<number>`(SELECT COUNT(*) FROM business_memberships bm WHERE bm.business_id = ${businesses.id} AND bm.status = 'active')`,
    products: sql<number>`(SELECT COUNT(*) FROM products p WHERE p.business_id = ${businesses.id})`,
    sales: sql<number>`(SELECT COUNT(*) FROM sales s WHERE s.business_id = ${businesses.id})`,
    revenue: sql<number>`(SELECT COALESCE(SUM(s.total), 0) FROM sales s WHERE s.business_id = ${businesses.id} AND s.status = 'completed')`,
  }).from(businesses).orderBy(desc(businesses.createdAt)).limit(100);
  return c.json({ data: rows });
});
