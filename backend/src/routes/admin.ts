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
    created_at: appUsers.createdAt, status: appUsers.status,
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

const audit=async(c:Context<AppEnv>,action:string,entityType:string,entityId:string|null,before:unknown,after:unknown)=>{
 await c.env.DB.prepare('INSERT INTO platform_audit_logs(id,actor_email,action,entity_type,entity_id,before_data,after_data,created_at) VALUES(?,?,?,?,?,?,?,?)').bind(crypto.randomUUID(),c.get('email'),action,entityType,entityId,before==null?null:JSON.stringify(before),after==null?null:JSON.stringify(after),new Date().toISOString()).run();
};
adminRoutes.get('/users/:id',async c=>{
 const id=c.req.param('id');const user=await c.env.DB.prepare('SELECT id,email,display_name,email_verified,status,created_at,updated_at FROM app_users WHERE id=?').bind(id).first();
 if(!user)return c.json({error:'USER_NOT_FOUND'},404);
 const memberships=await c.env.DB.prepare("SELECT bm.business_id,b.name AS business_name,bm.role,bm.status,bm.permissions FROM business_memberships bm JOIN businesses b ON b.id=bm.business_id WHERE bm.user_id=? ORDER BY b.name").bind(id).all();
 return c.json({data:{...user,memberships:memberships.results??[]}});
});
adminRoutes.patch('/users/:id',async c=>{
 const id=c.req.param('id'),p=await c.req.json().catch(()=>null);
 if(!p||typeof p!=='object'||!['active','suspended'].includes(p.status))return c.json({error:'VALIDATION_ERROR'},422);
 if(id===c.get('userId'))return c.json({error:'CANNOT_SUSPEND_SELF'},409);
 const before=await c.env.DB.prepare('SELECT id,email,status FROM app_users WHERE id=?').bind(id).first<any>();
 if(!before)return c.json({error:'USER_NOT_FOUND'},404);
 await c.env.DB.prepare('UPDATE app_users SET status=?,updated_at=? WHERE id=?').bind(p.status,new Date().toISOString(),id).run();
 if(p.status==='suspended')await c.env.DB.prepare('UPDATE auth_sessions SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL').bind(new Date().toISOString(),id).run();
 const after={...before,status:p.status};await audit(c,p.status==='suspended'?'user.suspend':'user.activate','user',id,before,after);
 return c.json({data:after});
});
adminRoutes.patch('/businesses/:id/status',async c=>{
 const id=c.req.param('id'),p=await c.req.json().catch(()=>null);
 if(!p||!['active','suspended'].includes(p.status))return c.json({error:'VALIDATION_ERROR'},422);
 const before=await c.env.DB.prepare('SELECT id,name,status FROM businesses WHERE id=?').bind(id).first<any>();
 if(!before)return c.json({error:'BUSINESS_NOT_FOUND'},404);
 await c.env.DB.prepare('UPDATE businesses SET status=?,updated_at=? WHERE id=?').bind(p.status,new Date().toISOString(),id).run();
 const after={...before,status:p.status};await audit(c,'business.status.update','business',id,before,after);return c.json({data:after});
});
adminRoutes.get('/audit',async c=>{
 const limit=Math.min(200,Math.max(1,Number(c.req.query('limit')||100)));
 const rows=await c.env.DB.prepare('SELECT id,actor_email,action,entity_type,entity_id,before_data,after_data,created_at FROM platform_audit_logs ORDER BY created_at DESC LIMIT ?').bind(limit).all();
 return c.json({data:rows.results??[]});
});
adminRoutes.get('/settings',async c=>{
 const rows=await c.env.DB.prepare('SELECT setting_key,setting_value,updated_by,updated_at FROM platform_settings ORDER BY setting_key').all();
 return c.json({data:(rows.results??[]).map((r:any)=>({...r,setting_value:JSON.parse(String(r.setting_value))}))});
});
adminRoutes.put('/settings/:key',async c=>{
 const key=c.req.param('key');if(!/^[a-z][a-z0-9_.-]{1,80}$/.test(key))return c.json({error:'INVALID_SETTING_KEY'},400);
 const value=await c.req.json().catch(()=>null);if(value===null)return c.json({error:'INVALID_JSON'},400);
 const before=await c.env.DB.prepare('SELECT setting_value FROM platform_settings WHERE setting_key=?').bind(key).first<any>();
 const serialized=JSON.stringify(value);if(serialized.length>10000)return c.json({error:'SETTING_TOO_LARGE'},413);
 const now=new Date().toISOString();
 await c.env.DB.prepare('INSERT INTO platform_settings(setting_key,setting_value,updated_by,updated_at) VALUES(?,?,?,?) ON CONFLICT(setting_key) DO UPDATE SET setting_value=excluded.setting_value,updated_by=excluded.updated_by,updated_at=excluded.updated_at').bind(key,serialized,c.get('email'),now).run();
 await audit(c,'setting.update','setting',key,before?JSON.parse(before.setting_value):null,value);return c.json({data:{key,value,updated_at:now}});
});
adminRoutes.get('/subscriptions',async c=>{
 const rows=await c.env.DB.prepare('SELECT s.*,b.name business_name,b.currency_code FROM platform_subscriptions s JOIN businesses b ON b.id=s.business_id ORDER BY s.updated_at DESC LIMIT 200').all();
 return c.json({data:rows.results??[]});
});
adminRoutes.put('/subscriptions/:businessId',async c=>{
 const businessId=c.req.param('businessId'),p=await c.req.json().catch(()=>null);
 if(!p||typeof p.plan_code!=='string'||!['free','plus','pro','business'].includes(p.plan_code)||!['trial','active','past_due','cancelled','expired'].includes(p.status))return c.json({error:'VALIDATION_ERROR'},422);
 const business=await c.env.DB.prepare('SELECT id FROM businesses WHERE id=?').bind(businessId).first();if(!business)return c.json({error:'BUSINESS_NOT_FOUND'},404);
 const now=new Date().toISOString(),id=crypto.randomUUID();
 const before=await c.env.DB.prepare('SELECT * FROM platform_subscriptions WHERE business_id=?').bind(businessId).first<any>();
 await c.env.DB.prepare('INSERT INTO platform_subscriptions(id,business_id,plan_code,status,started_at,ends_at,provider,external_reference,metadata,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(business_id) DO UPDATE SET plan_code=excluded.plan_code,status=excluded.status,started_at=excluded.started_at,ends_at=excluded.ends_at,provider=excluded.provider,external_reference=excluded.external_reference,metadata=excluded.metadata,updated_at=excluded.updated_at').bind(before?.id??id,businessId,p.plan_code,p.status,p.started_at??before?.started_at??now,p.ends_at??null,p.provider??null,p.external_reference??null,JSON.stringify(p.metadata??{}),before?.created_at??now,now).run();
 const after=await c.env.DB.prepare('SELECT * FROM platform_subscriptions WHERE business_id=?').bind(businessId).first();await audit(c,'subscription.upsert','subscription',businessId,before,after);return c.json({data:after});
});
adminRoutes.get('/ads',async c=>{const r=await c.env.DB.prepare('SELECT * FROM platform_ad_settings ORDER BY placement_key').all();return c.json({data:r.results??[]});});
adminRoutes.put('/ads/:placement',async c=>{
 const placement=c.req.param('placement');if(!/^[a-z0-9_.-]{2,80}$/.test(placement))return c.json({error:'INVALID_PLACEMENT'},400);
 const p=await c.req.json().catch(()=>null);if(!p||typeof p.enabled!=='boolean'||!['admob','none'].includes(p.provider)||!Number.isInteger(p.frequency_cap)||p.frequency_cap<0||p.frequency_cap>100)return c.json({error:'VALIDATION_ERROR'},422);
 const before=await c.env.DB.prepare('SELECT * FROM platform_ad_settings WHERE placement_key=?').bind(placement).first<any>(),now=new Date().toISOString();
 await c.env.DB.prepare('INSERT INTO platform_ad_settings(placement_key,enabled,provider,ad_unit_id,frequency_cap,updated_by,updated_at) VALUES(?,?,?,?,?,?,?) ON CONFLICT(placement_key) DO UPDATE SET enabled=excluded.enabled,provider=excluded.provider,ad_unit_id=excluded.ad_unit_id,frequency_cap=excluded.frequency_cap,updated_by=excluded.updated_by,updated_at=excluded.updated_at').bind(placement,p.enabled?1:0,p.provider,p.ad_unit_id??null,p.frequency_cap,c.get('email'),now).run();
 const after=await c.env.DB.prepare('SELECT * FROM platform_ad_settings WHERE placement_key=?').bind(placement).first();await audit(c,'ads.setting.update','ad_placement',placement,before,after);return c.json({data:after});
});
adminRoutes.get('/support',async c=>{
 const status=c.req.query('status'),allowed=['open','in_progress','resolved','closed'];
 if(status&&!allowed.includes(status))return c.json({error:'INVALID_STATUS'},400);
 const q=status?c.env.DB.prepare('SELECT t.*,u.email,u.display_name,b.name business_name FROM support_tickets t JOIN app_users u ON u.id=t.user_id LEFT JOIN businesses b ON b.id=t.business_id WHERE t.status=? ORDER BY t.created_at DESC LIMIT 200').bind(status):c.env.DB.prepare('SELECT t.*,u.email,u.display_name,b.name business_name FROM support_tickets t JOIN app_users u ON u.id=t.user_id LEFT JOIN businesses b ON b.id=t.business_id ORDER BY t.created_at DESC LIMIT 200');
 const rows=await q.all();return c.json({data:rows.results??[]});
});
adminRoutes.patch('/support/:id',async c=>{
 const id=c.req.param('id'),p=await c.req.json().catch(()=>null);
 if(!p||!['open','in_progress','resolved','closed'].includes(p.status)||typeof p.admin_reply!=='string'||p.admin_reply.length>4000)return c.json({error:'VALIDATION_ERROR'},422);
 const before=await c.env.DB.prepare('SELECT * FROM support_tickets WHERE id=?').bind(id).first<any>();if(!before)return c.json({error:'TICKET_NOT_FOUND'},404);
 const now=new Date().toISOString();await c.env.DB.prepare('UPDATE support_tickets SET status=?,admin_reply=?,updated_at=? WHERE id=?').bind(p.status,p.admin_reply.trim()||null,now,id).run();
 const after=await c.env.DB.prepare('SELECT * FROM support_tickets WHERE id=?').bind(id).first();await audit(c,'support.ticket.update','support_ticket',id,before,after);return c.json({data:after});
});
