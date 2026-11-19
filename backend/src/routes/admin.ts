import { Hono } from 'hono';
import { and, desc, eq, like, or, sql } from 'drizzle-orm';
import { db } from '../services/db.js';
import {
  appUsers, businesses, products, sales, salePayments, stockMovements, syncOperations,
  syncDevices, stockLevels, warehouses,
} from '../schema.js';
import { summarizeSyncStatuses } from '../services/admin-summary.js';
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
  const [users] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(appUsers);
  const [businessCount] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(businesses);
  const [productCount] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(products);
  const [saleCount] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(sales);
  const [movementCount] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(stockMovements);
  const [pending] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(syncOperations).where(eq(syncOperations.status, 'queued'));
  const [conflicts] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(syncOperations).where(eq(syncOperations.status, 'conflict'));
  const revenueByCurrency = await db.select({ currency_code: sales.currencyCode, total: sql.raw('COALESCE(SUM(sales.total), 0)').mapWith(Number) }).from(sales).where(eq(sales.status, 'completed')).groupBy(sales.currencyCode);
  const [active] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(businesses).where(eq(businesses.status, 'active'));
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
    members: sql.raw("(SELECT COUNT(*) FROM business_memberships bm WHERE bm.business_id = businesses.id AND bm.status = 'active')").mapWith(Number),
    products: sql.raw("(SELECT COUNT(*) FROM products p WHERE p.business_id = businesses.id)").mapWith(Number),
    sales: sql.raw("(SELECT COUNT(*) FROM sales s WHERE s.business_id = businesses.id)").mapWith(Number),
    revenue: sql.raw("(SELECT COALESCE(SUM(s.total), 0) FROM sales s WHERE s.business_id = businesses.id AND s.status = 'completed')").mapWith(Number),
  }).from(businesses).orderBy(desc(businesses.createdAt)).limit(100);
  return c.json({ data: rows });
});

adminRoutes.get('/sales', async (c) => {
  const rows = await db.select({
    id: sales.id, sale_number: sales.saleNumber, business_id: sales.businessId,
    business_name: businesses.name, currency_code: sales.currencyCode, total: sales.total,
    amount_paid: sales.amountPaid, status: sales.status, sold_at: sales.soldAt,
    created_at: sales.createdAt, payment_method: salePayments.paymentMethod,
    payment_status: salePayments.status, actor_email: appUsers.email,
  }).from(sales)
    .leftJoin(businesses, eq(businesses.id, sales.businessId))
    .leftJoin(salePayments, eq(salePayments.saleId, sales.id))
    .leftJoin(appUsers, eq(appUsers.id, sales.createdBy))
    .orderBy(desc(sales.soldAt)).limit(50);
  return c.json({ data: rows });
});

adminRoutes.get('/sync', async (c) => {
  const status = c.req.query('status');
  const allowed = ['queued', 'applied', 'conflict', 'rejected', 'failed', 'processing'];
  if (status && !allowed.includes(status)) return c.json({ error: 'INVALID_STATUS' }, 400);
  const counts = await db.select({ status: syncOperations.status, count: sql.raw('count(*)').mapWith(Number) })
    .from(syncOperations).groupBy(syncOperations.status);
  const summary = summarizeSyncStatuses(counts);
  const base = db.select({
    id: syncOperations.id, business_id: syncOperations.businessId, business_name: businesses.name,
    entity_type: syncOperations.entityType, entity_id: syncOperations.entityId,
    operation_type: syncOperations.operationType, status: syncOperations.status,
    created_at: syncOperations.createdAt, processed_at: syncOperations.processedAt,
    device_id: syncOperations.deviceId, platform: syncDevices.platform, actor_email: appUsers.email,
    result: syncOperations.result,
  }).from(syncOperations)
    .leftJoin(businesses, eq(businesses.id, syncOperations.businessId))
    .leftJoin(syncDevices, eq(syncDevices.id, syncOperations.deviceId))
    .leftJoin(appUsers, eq(appUsers.id, syncDevices.userId));
  const operations = status
    ? await base.where(eq(syncOperations.status, status)).orderBy(desc(syncOperations.createdAt)).limit(100)
    : await base.orderBy(desc(syncOperations.createdAt)).limit(100);
  return c.json({ data: { summary, operations } });
});

adminRoutes.get('/inventory', async (c) => {
  const lowStock = sql.raw("COALESCE(stock_levels.quantity, 0) <= COALESCE(json_extract(products.metadata, '$.min_quantity'), 0)");
  const rows = await db.select({
    business_id: products.businessId, business_name: businesses.name,
    product_id: products.id, product_name: products.name, sku: products.sku,
    warehouse_name: warehouses.name, quantity: sql.raw('COALESCE(stock_levels.quantity, 0)').mapWith(Number),
    min_quantity: sql.raw("COALESCE(json_extract(products.metadata, '$.min_quantity'), 0)").mapWith(Number),
    sale_price: products.salePrice, currency_code: businesses.currencyCode,
    updated_at: stockLevels.updatedAt,
  }).from(products)
    .leftJoin(businesses, eq(businesses.id, products.businessId))
    .leftJoin(warehouses, and(eq(warehouses.businessId, products.businessId), eq(warehouses.isDefault, 1)))
    .leftJoin(stockLevels, and(eq(stockLevels.businessId, products.businessId), eq(stockLevels.productId, products.id), eq(stockLevels.warehouseId, warehouses.id)))
    .where(and(eq(products.isActive, 1), eq(products.trackStock, 1), lowStock))
    .orderBy(sql.raw('COALESCE(stock_levels.quantity, 0) ASC')).limit(100);
  const [count] = await db.select({ count: sql.raw('count(*)').mapWith(Number) }).from(products)
    .leftJoin(warehouses, and(eq(warehouses.businessId, products.businessId), eq(warehouses.isDefault, 1)))
    .leftJoin(stockLevels, and(eq(stockLevels.businessId, products.businessId), eq(stockLevels.productId, products.id), eq(stockLevels.warehouseId, warehouses.id)))
    .where(and(eq(products.isActive, 1), eq(products.trackStock, 1), lowStock));
  return c.json({ data: rows, count: count.count, capped: count.count > rows.length });
});


// Platform search normalization keeps queries bounded and whitespace-free.
export function normalizeAdminSearch(raw?: string): string {
  return (raw ?? '').trim().slice(0, 80);
}

adminRoutes.get('/products', async (c) => {
  const query = normalizeAdminSearch(c.req.query('q'));
  const businessId = c.req.query('business_id')?.trim();
  const where = and(
    businessId ? eq(products.businessId, businessId) : undefined,
    query ? or(
      like(products.name, `%${query}%`),
      like(products.sku, `%${query}%`),
      like(products.barcode, `%${query}%`),
      like(businesses.name, `%${query}%`),
    ) : undefined,
  );
  const rows = await db.select({
    id: products.id, business_id: products.businessId, business_name: businesses.name,
    name: products.name, sku: products.sku, barcode: products.barcode, unit: products.unit,
    purchase_price: products.purchasePrice, sale_price: products.salePrice, tax_rate: products.taxRate,
    is_active: products.isActive, track_stock: products.trackStock,
    min_quantity: sql<number>`COALESCE(json_extract(${products.metadata}, '$.min_quantity'), 0)`.mapWith(Number),
    quantity: sql<number>`COALESCE(${stockLevels.quantity}, 0)`.mapWith(Number),
    warehouse_name: warehouses.name, currency_code: businesses.currencyCode, updated_at: products.updatedAt,
  }).from(products)
    .leftJoin(businesses, eq(businesses.id, products.businessId))
    .leftJoin(warehouses, and(eq(warehouses.businessId, products.businessId), eq(warehouses.isDefault, 1)))
    .leftJoin(stockLevels, and(eq(stockLevels.businessId, products.businessId), eq(stockLevels.productId, products.id), eq(stockLevels.warehouseId, warehouses.id)))
    .where(where).orderBy(desc(products.updatedAt)).limit(100);
  const [count] = await db.select({ count: sql<number>`count(*)`.mapWith(Number) })
    .from(products).leftJoin(businesses, eq(businesses.id, products.businessId)).where(where);
  return c.json({ data: rows, count: count.count, capped: count.count > rows.length });
});

adminRoutes.get('/movements', async (c) => {
  const query = normalizeAdminSearch(c.req.query('q'));
  const businessId = c.req.query('business_id')?.trim();
  const movementType = c.req.query('movement_type')?.trim();
  const allowed = ['opening', 'purchase', 'sale', 'return_in', 'return_out', 'adjustment', 'transfer_in', 'transfer_out'];
  if (movementType && !allowed.includes(movementType)) return c.json({ error: 'INVALID_MOVEMENT_TYPE' }, 400);
  const where = and(
    businessId ? eq(stockMovements.businessId, businessId) : undefined,
    movementType ? eq(stockMovements.movementType, movementType) : undefined,
    query ? or(
      like(products.name, `%${query}%`),
      like(products.sku, `%${query}%`),
      like(businesses.name, `%${query}%`),
      like(stockMovements.note, `%${query}%`),
      like(stockMovements.sourceId, `%${query}%`),
      like(appUsers.email, `%${query}%`),
    ) : undefined,
  );
  const rows = await db.select({
    id: stockMovements.id, business_id: stockMovements.businessId, business_name: businesses.name,
    product_name: products.name, sku: products.sku, warehouse_name: warehouses.name,
    movement_type: stockMovements.movementType, quantity_delta: stockMovements.quantityDelta,
    unit_cost: stockMovements.unitCost, currency_code: businesses.currencyCode, source_type: stockMovements.sourceType, source_id: stockMovements.sourceId,
    note: stockMovements.note, actor_email: appUsers.email, occurred_at: stockMovements.occurredAt,
  }).from(stockMovements)
    .leftJoin(products, eq(products.id, stockMovements.productId))
    .leftJoin(businesses, eq(businesses.id, stockMovements.businessId))
    .leftJoin(warehouses, eq(warehouses.id, stockMovements.warehouseId))
    .leftJoin(appUsers, eq(appUsers.id, stockMovements.actorUserId))
    .where(where).orderBy(desc(stockMovements.occurredAt)).limit(100);
  const [count] = await db.select({ count: sql<number>`count(*)`.mapWith(Number) })
    .from(stockMovements).leftJoin(products, eq(products.id, stockMovements.productId))
    .leftJoin(businesses, eq(businesses.id, stockMovements.businessId))
    .leftJoin(appUsers, eq(appUsers.id, stockMovements.actorUserId)).where(where);
  return c.json({ data: rows, count: count.count, capped: count.count > rows.length });
});

// Read-only platform user directory. Only verified platform administrators reach this route.
adminRoutes.get('/users', async (c) => {
  const query = normalizeAdminSearch(c.req.query('q'));
  const fields = {
    id: appUsers.id,
    email: appUsers.email,
    display_name: appUsers.displayName,
    created_at: appUsers.createdAt,
    active_businesses: sql<number>`(SELECT COUNT(*) FROM business_memberships bm WHERE bm.user_id = app_users.id AND bm.status = 'active')`,
    organizations: sql<number>`(SELECT COUNT(*) FROM organization_memberships om WHERE om.user_id = app_users.id AND om.status = 'active')`,
    devices: sql<number>`(SELECT COUNT(*) FROM sync_devices sd WHERE sd.user_id = app_users.id)`,
    last_seen: sql<string | null>`(SELECT MAX(sd.last_seen_at) FROM sync_devices sd WHERE sd.user_id = app_users.id)`,
  };
  const rows = query
    ? await db.select(fields).from(appUsers)
      .where(or(like(appUsers.email, `%${query}%`), like(appUsers.displayName, `%${query}%`)))
      .orderBy(desc(appUsers.createdAt)).limit(100)
    : await db.select(fields).from(appUsers).orderBy(desc(appUsers.createdAt)).limit(100);
  return c.json({ data: rows, count: rows.length, capped: rows.length === 100 });
});
