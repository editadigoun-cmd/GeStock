import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, sql } from 'drizzle-orm';
import { db } from '../services/db.js';
import { appUsers, businesses, businessMemberships, organizationMemberships, organizations, products, stockMovements, stockLevels, syncDevices, syncOperations, warehouses } from '../schema.js';
import type { AppEnv } from '../middleware/auth.js';

export const syncRoutes = new Hono<AppEnv>();

const deviceSchema = z.object({
  device_key: z.string().uuid(),
  platform: z.enum(['android', 'ios', 'web', 'other']),
});
syncRoutes.post('/devices/register', async (c) => {
  const parsed = deviceSchema.safeParse(await c.req.json());
  if (!parsed.success) return c.json({ error: 'VALIDATION_ERROR', details: parsed.error.flatten() }, 422);
  const result = await db.transaction(async (tx) => {
    let [user] = await tx.select({ id: appUsers.id }).from(appUsers).where(eq(appUsers.authSubject, c.get('userId'))).limit(1);
    if (!user) [user] = await tx.insert(appUsers).values({ authSubject: c.get('userId') }).returning({ id: appUsers.id });
    const [device] = await tx.insert(syncDevices).values({ userId: user.id, deviceKey: parsed.data.device_key, platform: parsed.data.platform, lastSeenAt: new Date() })
      .onConflictDoUpdate({ target: [syncDevices.userId, syncDevices.deviceKey], set: { platform: parsed.data.platform, lastSeenAt: new Date() } })
      .returning({ id: syncDevices.id });
    return device;
  });
  return c.json({ data: result });
});

const operationSchema = z.object({
  id: z.string().uuid(),
  business_id: z.string().uuid(),
  entity_type: z.enum(['business', 'product', 'stock_movement']),
  entity_id: z.string().uuid(),
  operation: z.string().min(1).max(40),
  payload: z.record(z.unknown()),
  created_at: z.string().datetime({ offset: true }).optional(),
});
const batchSchema = z.object({ device_id: z.string().uuid(), operations: z.array(operationSchema).min(1).max(50) });

async function applyOperation(authSubject: string, deviceId: string, op: z.infer<typeof operationSchema>) {
  return db.transaction(async (tx) => {
    let [user] = await tx.select({ id: appUsers.id }).from(appUsers).where(eq(appUsers.authSubject, authSubject)).limit(1);
    if (!user) [user] = await tx.insert(appUsers).values({ authSubject }).returning({ id: appUsers.id });
    const [device] = await tx.select({ id: syncDevices.id, userId: syncDevices.userId }).from(syncDevices)
      .where(and(eq(syncDevices.id, deviceId), eq(syncDevices.userId, user.id))).limit(1);
    if (!device) throw new Error('DEVICE_NOT_REGISTERED');

    if (op.entity_type === 'business') {
      const p = op.payload;
      const businessId = op.business_id;
      const existing = await tx.select({ id: businesses.id }).from(businesses).where(eq(businesses.id, businessId)).limit(1);
      if (!existing.length) {
        const name = String(p.name ?? '').trim();
        const businessType = String(p.business_type ?? 'general');
        const countryCode = String(p.country_code ?? 'BJ');
        const currencyCode = String(p.currency_code ?? 'XOF');
        const timezone = String(p.timezone ?? 'Africa/Porto-Novo');
        const warehouseId = String(p.default_warehouse_id ?? '');
        if (!name || !z.string().uuid().safeParse(warehouseId).success || !/^[A-Z]{2}$/.test(countryCode) || !/^[A-Z]{3}$/.test(currencyCode)) {
          throw new Error('INVALID_BUSINESS_PAYLOAD');
        }
        const [org] = await tx.insert(organizations).values({ name, ownerUserId: user.id }).returning({ id: organizations.id });
        await tx.insert(organizationMemberships).values({ organizationId: org.id, userId: user.id, role: 'owner', status: 'active' });
        await tx.insert(businesses).values({ id: businessId, organizationId: org.id, name, businessType, countryCode, currencyCode, timezone });
        await tx.insert(businessMemberships).values({ businessId, userId: user.id, role: 'owner', permissions: { all: true }, status: 'active' });
        await tx.insert(warehouses).values({ id: warehouseId, businessId, name: 'Dépôt principal', isDefault: true });
      } else {
        const membership = await tx.select({ id: businessMemberships.id }).from(businessMemberships)
          .where(and(eq(businessMemberships.businessId, businessId), eq(businessMemberships.userId, user.id), eq(businessMemberships.status, 'active'))).limit(1);
        if (!membership.length) throw new Error('FORBIDDEN');
      }
    }

    const membership = await tx.select({ id: businessMemberships.id }).from(businessMemberships)
      .where(and(eq(businessMemberships.businessId, op.business_id), eq(businessMemberships.userId, user.id), eq(businessMemberships.status, 'active'))).limit(1);
    if (!membership.length) throw new Error('FORBIDDEN');

    const [already] = await tx.select({ id: syncOperations.id, status: syncOperations.status, result: syncOperations.result })
      .from(syncOperations).where(and(eq(syncOperations.businessId, op.business_id), eq(syncOperations.operationKey, op.id))).limit(1);
    if (already) return { status: already.status, result: already.result, duplicate: true };

    const [queued] = await tx.insert(syncOperations).values({
      businessId: op.business_id, deviceId, operationKey: op.id, entityType: op.entity_type,
      entityId: op.entity_id, operationType: op.operation, payload: op.payload, status: 'queued',
    }).returning({ id: syncOperations.id });

    let result: Record<string, unknown>;
    if (op.entity_type === 'business') {
      result = { id: op.business_id, synced: true };
    } else if (op.entity_type === 'product') {
      const p = op.payload;
      const productId = String(p.id ?? op.entity_id);
      if (productId !== op.entity_id || String(p.business_id ?? op.business_id) !== op.business_id) throw new Error('INVALID_PRODUCT_PAYLOAD');
      const name = String(p.name ?? '').trim();
      if (!name) throw new Error('INVALID_PRODUCT_PAYLOAD');
      const [current] = await tx.select({ id: products.id, businessId: products.businessId }).from(products).where(eq(products.id, productId)).limit(1);
      if (current && current.businessId !== op.business_id) throw new Error('PRODUCT_BUSINESS_MISMATCH');
      const values = {
        id: productId, businessId: op.business_id, name, sku: p.sku ? String(p.sku) : null,
        barcode: p.barcode ? String(p.barcode) : null, unit: String(p.unit ?? 'unité'),
        purchasePrice: Number(p.purchase_price ?? 0), salePrice: Number(p.sale_price ?? 0),
        taxRate: Number(p.tax_rate ?? 0), updatedAt: p.updated_at ? String(p.updated_at) : new Date().toISOString(),
      };
      if (![values.purchasePrice, values.salePrice, values.taxRate].every(v => Number.isFinite(Number(v)) && Number(v) >= 0)) throw new Error('INVALID_PRODUCT_PRICES');
      if (current) {
        await tx.update(products).set({ name: values.name, sku: values.sku, barcode: values.barcode, unit: values.unit, purchasePrice: values.purchasePrice, salePrice: values.salePrice, taxRate: values.taxRate, updatedAt: values.updatedAt }).where(eq(products.id, productId));
      } else {
        await tx.insert(products).values(values);
      }
      result = { id: productId, synced: true };
    } else {
      const p = op.payload;
      const movementId = String(p.id ?? op.entity_id);
      const businessId = String(p.business_id ?? op.business_id);
      const warehouseId = String(p.warehouse_id ?? '');
      const productId = String(p.product_id ?? '');
      const delta = Number(p.quantity_delta);
      const movementType = String(p.movement_type ?? '');
      if (movementId !== op.entity_id || businessId !== op.business_id || !Number.isFinite(delta) || delta === 0 ||
          !['opening', 'purchase', 'sale', 'return_in', 'return_out', 'adjustment', 'transfer_in', 'transfer_out'].includes(movementType)) {
        throw new Error('INVALID_STOCK_MOVEMENT');
      }
      const [existingMovement] = await tx.select({ id: stockMovements.id }).from(stockMovements).where(eq(stockMovements.id, movementId)).limit(1);
      if (existingMovement) {
        result = { id: movementId, synced: true, duplicate: true };
      } else {
        const [product] = await tx.select({ id: products.id }).from(products).where(and(eq(products.id, productId), eq(products.businessId, businessId))).limit(1);
        const [warehouse] = await tx.select({ id: warehouses.id }).from(warehouses).where(and(eq(warehouses.id, warehouseId), eq(warehouses.businessId, businessId))).limit(1);
        if (!product || !warehouse) throw new Error('PRODUCT_OR_WAREHOUSE_NOT_FOUND');
        await tx.insert(stockMovements).values({
          id: movementId, businessId, warehouseId, productId, movementType, quantityDelta: delta,
          note: p.note ? String(p.note).slice(0, 500) : null,
          occurredAt: p.occurred_at ? String(p.occurred_at) : new Date().toISOString(),
          actorUserId: user.id,
        });
        const [level] = await tx.insert(stockLevels).values({ businessId, warehouseId, productId, quantity: delta, updatedAt: new Date().toISOString() })
          .onConflictDoUpdate({
            target: [stockLevels.warehouseId, stockLevels.productId],
            set: { quantity: sql`${stockLevels.quantity} + ${delta}`, updatedAt: new Date() },
          }).returning({ quantity: stockLevels.quantity });
        if (Number(level.quantity) < 0) throw new Error('INSUFFICIENT_STOCK');
        result = { id: movementId, synced: true, quantity: level.quantity };
      }
    }
    await tx.update(syncOperations).set({ status: 'applied', result, processedAt: new Date().toISOString() }).where(eq(syncOperations.id, queued.id));
    return { status: 'applied', result, duplicate: false };
  });
}

syncRoutes.post('/batch', async (c) => {
  const parsed = batchSchema.safeParse(await c.req.json());
  if (!parsed.success) return c.json({ error: 'VALIDATION_ERROR', details: parsed.error.flatten() }, 422);
  const { device_id, operations } = parsed.data;
  const results = [];
  for (const op of operations) {
    try {
      const outcome = await applyOperation(c.get('userId'), device_id, op);
      results.push({ operation_id: op.id, ...outcome });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'SYNC_FAILED';
      const status = message === 'FORBIDDEN' || message === 'DEVICE_NOT_REGISTERED' ? 'rejected' : 'conflict';
      results.push({ operation_id: op.id, status, error: message });
    }
  }
  return c.json({ data: results });
});
