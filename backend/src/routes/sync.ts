import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, sql } from 'drizzle-orm';
import { db } from '../services/db.js';
import { appUsers, businesses, businessMemberships, organizationMemberships, organizations, products, stockMovements, stockLevels, syncDevices, syncOperations, warehouses } from '../schema.js';
import { saleInputSchema, createSaleTransaction } from '../services/sales.js';
import type { AppEnv } from '../middleware/auth.js';

export const syncRoutes = new Hono<AppEnv>();

const deviceSchema = z.object({
  device_key: z.string().uuid(),
  platform: z.enum(['android', 'ios', 'web', 'other']),
});

async function getOrCreateUser(authSubject: string) {
  const now = new Date().toISOString();
  await db.insert(appUsers).values({ authSubject, createdAt: now, updatedAt: now }).onConflictDoNothing();
  const [user] = await db.select({ id: appUsers.id }).from(appUsers)
    .where(eq(appUsers.authSubject, authSubject)).limit(1);
  if (!user) throw new Error('USER_CREATE_FAILED');
  return user;
}

syncRoutes.post('/devices/register', async (c) => {
  const parsed = deviceSchema.safeParse(await c.req.json());
  if (!parsed.success) return c.json({ error: 'VALIDATION_ERROR', details: parsed.error.flatten() }, 422);
  const user = await getOrCreateUser(c.get('userId'));
  const now = new Date().toISOString();
  const [device] = await db.insert(syncDevices).values({
    userId: user.id, deviceKey: parsed.data.device_key, platform: parsed.data.platform, lastSeenAt: now,
  }).onConflictDoUpdate({
    target: [syncDevices.userId, syncDevices.deviceKey],
    set: { platform: parsed.data.platform, lastSeenAt: now },
  }).returning({ id: syncDevices.id });
  return c.json({ data: device });
});

const operationSchema = z.object({
  id: z.string().uuid(),
  business_id: z.string().uuid(),
  entity_type: z.enum(['business', 'product', 'stock_movement', 'sale']),
  entity_id: z.string().uuid(),
  operation: z.string().min(1).max(40),
  payload: z.record(z.unknown()),
  created_at: z.string().datetime({ offset: true }).optional(),
});
const batchSchema = z.object({ device_id: z.string().uuid(), operations: z.array(operationSchema).min(1).max(50) });

function operationRecord(deviceId: string, op: z.infer<typeof operationSchema>, result: Record<string, unknown>) {
  return {
    id: crypto.randomUUID(),
    businessId: op.business_id,
    deviceId,
    operationKey: op.id,
    entityType: op.entity_type,
    entityId: op.entity_id,
    operationType: op.operation,
    payload: op.payload,
    status: 'applied',
    result,
    processedAt: new Date().toISOString(),
  };
}

async function applyOperation(authSubject: string, deviceId: string, op: z.infer<typeof operationSchema>) {
  const user = await getOrCreateUser(authSubject);
  const [device] = await db.select({ id: syncDevices.id }).from(syncDevices)
    .where(and(eq(syncDevices.id, deviceId), eq(syncDevices.userId, user.id))).limit(1);
  if (!device) throw new Error('DEVICE_NOT_REGISTERED');

  const [already] = await db.select({ status: syncOperations.status, result: syncOperations.result })
    .from(syncOperations).where(and(eq(syncOperations.businessId, op.business_id), eq(syncOperations.operationKey, op.id))).limit(1);
  if (already) return { status: already.status, result: already.result, duplicate: true };

  if (op.entity_type === 'business') {
    if (op.entity_id !== op.business_id) throw new Error('INVALID_BUSINESS_PAYLOAD');
    const p = op.payload;
    const [existing] = await db.select({ id: businesses.id }).from(businesses).where(eq(businesses.id, op.business_id)).limit(1);
    const result = { id: op.business_id, synced: true };
    if (existing) {
      const [membership] = await db.select({ id: businessMemberships.id }).from(businessMemberships)
        .where(and(eq(businessMemberships.businessId, op.business_id), eq(businessMemberships.userId, user.id), eq(businessMemberships.status, 'active'))).limit(1);
      if (!membership) throw new Error('FORBIDDEN');
      await db.insert(syncOperations).values(operationRecord(deviceId, op, result));
    } else {
      const name = String(p.name ?? '').trim();
      const businessType = String(p.business_type ?? 'general');
      const countryCode = String(p.country_code ?? 'BJ');
      const currencyCode = String(p.currency_code ?? 'XOF');
      const timezone = String(p.timezone ?? 'Africa/Porto-Novo');
      const warehouseId = String(p.default_warehouse_id ?? '');
      if (!name || !z.string().uuid().safeParse(warehouseId).success ||
          !/^[A-Z]{2}$/.test(countryCode) || !/^[A-Z]{3}$/.test(currencyCode)) {
        throw new Error('INVALID_BUSINESS_PAYLOAD');
      }
      const now = new Date().toISOString();
      const orgId = crypto.randomUUID();
      await db.batch([
        db.insert(organizations).values({ id: orgId, name, ownerUserId: user.id, createdAt: now, updatedAt: now }),
        db.insert(organizationMemberships).values({ id: crypto.randomUUID(), organizationId: orgId, userId: user.id, role: 'owner', status: 'active', createdAt: now }),
        db.insert(businesses).values({ id: op.business_id, organizationId: orgId, name, businessType, countryCode, currencyCode, timezone, createdAt: now, updatedAt: now }),
        db.insert(businessMemberships).values({ id: crypto.randomUUID(), businessId: op.business_id, userId: user.id, role: 'owner', permissions: { all: true }, status: 'active', createdAt: now }),
        db.insert(warehouses).values({ id: warehouseId, businessId: op.business_id, name: 'Dépôt principal', isDefault: 1, createdAt: now }),
        db.insert(syncOperations).values(operationRecord(deviceId, op, result)),
      ]);
    }
    return { status: 'applied', result, duplicate: false };
  }

  const [membership] = await db.select({ id: businessMemberships.id }).from(businessMemberships)
    .where(and(eq(businessMemberships.businessId, op.business_id), eq(businessMemberships.userId, user.id), eq(businessMemberships.status, 'active'))).limit(1);
  if (!membership) throw new Error('FORBIDDEN');

  if (op.entity_type === 'sale') {
    const parsedSale = saleInputSchema.safeParse({ ...op.payload, id: op.entity_id, business_id: op.business_id });
    if (!parsedSale.success) throw new Error('INVALID_SALE_PAYLOAD');
    if (op.operation !== 'create') throw new Error('INVALID_SALE_OPERATION');
    const result = { id: op.entity_id, synced: true };
    const outcome = await createSaleTransaction(user.id, parsedSale.data, operationRecord(deviceId, op, result));
    return { status: 'applied', result: { ...result, duplicate: outcome.duplicate }, duplicate: outcome.duplicate };
  }

  if (op.entity_type === 'product') {
    const p = op.payload;
    const productId = String(p.id ?? op.entity_id);
    if (productId !== op.entity_id || String(p.business_id ?? op.business_id) !== op.business_id) throw new Error('INVALID_PRODUCT_PAYLOAD');
    const name = String(p.name ?? '').trim();
    if (!name) throw new Error('INVALID_PRODUCT_PAYLOAD');
    const values = {
      id: productId, businessId: op.business_id, name, sku: p.sku ? String(p.sku) : null,
      barcode: p.barcode ? String(p.barcode) : null, unit: String(p.unit ?? 'unité'),
      purchasePrice: Number(p.purchase_price ?? 0), salePrice: Number(p.sale_price ?? 0),
      taxRate: Number(p.tax_rate ?? 0), metadata: { min_quantity: Number(p.min_quantity ?? 0) },
      updatedAt: p.updated_at ? String(p.updated_at) : new Date().toISOString(),
    };
    if (![values.purchasePrice, values.salePrice, values.taxRate, values.metadata.min_quantity].every(v => Number.isFinite(v) && v >= 0)) throw new Error('INVALID_PRODUCT_PRICES');
    const [current] = await db.select({ id: products.id, businessId: products.businessId }).from(products).where(eq(products.id, productId)).limit(1);
    if (current && current.businessId !== op.business_id) throw new Error('PRODUCT_BUSINESS_MISMATCH');
    const result = { id: productId, synced: true };
    const write = current
      ? db.update(products).set({ name: values.name, sku: values.sku, barcode: values.barcode, unit: values.unit, purchasePrice: values.purchasePrice, salePrice: values.salePrice, taxRate: values.taxRate, metadata: values.metadata, updatedAt: values.updatedAt }).where(eq(products.id, productId))
      : db.insert(products).values(values);
    await db.batch([write, db.insert(syncOperations).values(operationRecord(deviceId, op, result))]);
    return { status: 'applied', result, duplicate: false };
  }

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
  const [existingMovement] = await db.select({ id: stockMovements.id }).from(stockMovements).where(eq(stockMovements.id, movementId)).limit(1);
  const result = { id: movementId, synced: true, duplicate: Boolean(existingMovement) };
  if (existingMovement) {
    await db.insert(syncOperations).values(operationRecord(deviceId, op, result));
    return { status: 'applied', result, duplicate: false };
  }
  const [product] = await db.select({ id: products.id }).from(products)
    .where(and(eq(products.id, productId), eq(products.businessId, businessId))).limit(1);
  const [warehouse] = await db.select({ id: warehouses.id }).from(warehouses)
    .where(and(eq(warehouses.id, warehouseId), eq(warehouses.businessId, businessId))).limit(1);
  if (!product || !warehouse) throw new Error('PRODUCT_OR_WAREHOUSE_NOT_FOUND');
  const now = new Date().toISOString();
  await db.batch([
    db.insert(stockMovements).values({
      id: movementId, businessId, warehouseId, productId, movementType, quantityDelta: delta,
      note: p.note ? String(p.note).slice(0, 500) : null,
      occurredAt: p.occurred_at ? String(p.occurred_at) : now, actorUserId: user.id, createdAt: now,
    }),
    db.insert(stockLevels).values({
      id: crypto.randomUUID(), businessId, warehouseId, productId, quantity: delta, updatedAt: now,
    }).onConflictDoUpdate({
      target: [stockLevels.warehouseId, stockLevels.productId],
      set: { quantity: sql`${stockLevels.quantity} + ${delta}`, updatedAt: now },
    }),
    db.insert(syncOperations).values(operationRecord(deviceId, op, result)),
  ]);
  return { status: 'applied', result, duplicate: false };
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
}
});