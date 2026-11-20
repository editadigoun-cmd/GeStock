import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, sql } from 'drizzle-orm';
import { db } from '../services/db.js';
import { appUsers, businesses, businessMemberships, organizationMemberships, organizations, products, customers, customerPayments, saleReturns, saleReturnItems, sales, saleItems, suppliers, purchases, purchaseItems, expenses, stockMovements, stockLevels, syncDevices, syncOperations, warehouses } from '../schema.js';
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
  entity_type: z.enum(['business', 'product', 'customer', 'supplier', 'purchase', 'expense', 'customer_payment', 'sale_return', 'stock_movement', 'sale']),
  entity_id: z.string().uuid(),
  operation: z.string().min(1).max(40),
  payload: z.record(z.string(), z.unknown()),
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

  if (op.entity_type === 'sale_return') {
    const p=op.payload; const returnId=String(p.id??op.entity_id); const saleId=String(p.sale_id??'');
    const reason=String(p.reason??'').trim(); const refundMethod=String(p.refund_method??'cash');
    const returnedAt=String(p.returned_at??new Date().toISOString()); const items=Array.isArray(p.items)?p.items:[];
    if(returnId!==op.entity_id||String(p.business_id??op.business_id)!==op.business_id||!z.string().uuid().safeParse(saleId).success||!reason||!['cash','mobile_money','card','bank_transfer','store_credit','other'].includes(refundMethod)||items.length<1)throw new Error('INVALID_RETURN_PAYLOAD');
    const [sale]=await db.select().from(sales).where(and(eq(sales.id,saleId),eq(sales.businessId,op.business_id))).limit(1);
    if(!sale)throw new Error('SALE_NOT_FOUND');
    const soldItems=await db.select().from(saleItems).where(eq(saleItems.saleId,saleId));
    const soldMap=new Map(soldItems.map(x=>[x.id,x]));
    const returnRows=[];const stockWrites:any[]=[];let refundAmount=0;const returnQuantities=new Map<string,number>();
    for(const item of items){
      const saleItemId=String(item.sale_item_id??'');const qty=Number(item.quantity);
      const original=soldMap.get(saleItemId);if(!original||!Number.isFinite(qty)||qty<=0)throw new Error('INVALID_RETURN_ITEM');
      const prior=await db.select({quantity:saleReturnItems.quantity}).from(saleReturnItems).where(eq(saleReturnItems.saleItemId,saleItemId));
      const returned=prior.reduce((sum,x)=>sum+Number(x.quantity),0);if(returned+qty>Number(original.quantity)+1e-8)throw new Error('RETURN_QUANTITY_EXCEEDS_SOLD');returnQuantities.set(saleItemId,returned+qty);
      const unit=Number(original.lineTotal)/Number(original.quantity);const lineRefund=unit*qty;refundAmount+=lineRefund;
      returnRows.push({id:crypto.randomUUID(),returnId,saleItemId,productId:original.productId,productNameSnapshot:original.productNameSnapshot,quantity:qty,unitPrice:Number(original.unitPrice),refundAmount:lineRefund});
      if(original.productId){
        const [movement]=await db.select({warehouseId:stockMovements.warehouseId}).from(stockMovements).where(and(eq(stockMovements.sourceType,'sale'),eq(stockMovements.sourceId,saleId),eq(stockMovements.productId,original.productId))).limit(1);
        if(movement){
          stockWrites.push(db.insert(stockMovements).values({id:crypto.randomUUID(),businessId:op.business_id,warehouseId:movement.warehouseId,productId:original.productId,movementType:'sale_return',quantityDelta:qty,sourceType:'sale_return',sourceId:returnId,actorUserId:user.id,occurredAt:returnedAt,createdAt:returnedAt}));
          stockWrites.push(db.insert(stockLevels).values({id:crypto.randomUUID(),businessId:op.business_id,warehouseId:movement.warehouseId,productId:original.productId,quantity:qty,updatedAt:returnedAt}).onConflictDoUpdate({target:[stockLevels.warehouseId,stockLevels.productId],set:{quantity:sql`${stockLevels.quantity} + ${qty}`,updatedAt:returnedAt}}));
        }
      }
    }
    const number=String(p.return_number??('RET-'+returnId.slice(0,8).toUpperCase()));
    const [existing]=await db.select({id:saleReturns.id}).from(saleReturns).where(eq(saleReturns.id,returnId)).limit(1);
    if(existing)return {status:'applied',result:{id:returnId,synced:true,duplicate:true},duplicate:true};
    const fullyReturned=soldItems.every(item=>{const prior=returnQuantities.get(item.id);if(prior!==undefined)return prior>=Number(item.quantity)-1e-8;return false;});
    const outstandingCredit=Math.max(0,Number(sale.total)-Number(sale.amountPaid));const creditAdjustment=Math.min(refundAmount,outstandingCredit);
    await db.batch([db.insert(saleReturns).values({id:returnId,businessId:op.business_id,saleId,returnNumber:number,reason,refundMethod,refundAmount,status:'completed',returnedAt,createdBy:user.id}),...returnRows.map(x=>db.insert(saleReturnItems).values(x)),...stockWrites,...(sale.customerId&&creditAdjustment>0?[db.update(customers).set({balanceDue:sql`MAX(${customers.balanceDue} - ${creditAdjustment}, 0)`}).where(and(eq(customers.id,sale.customerId),eq(customers.businessId,op.business_id)))]:[]),db.update(sales).set({status:fullyReturned?'returned':'partially_returned'}).where(and(eq(sales.id,saleId),eq(sales.businessId,op.business_id))),db.insert(syncOperations).values(operationRecord(deviceId,op,{id:returnId,synced:true}))]);
    return {status:'applied',result:{id:returnId,synced:true,refund_amount:refundAmount},duplicate:false};
  }

  if (op.entity_type === 'sale') {
    const parsedSale = saleInputSchema.safeParse({ ...op.payload, id: op.entity_id, business_id: op.business_id });
    if (!parsedSale.success) throw new Error('INVALID_SALE_PAYLOAD');
    if (op.operation !== 'create') throw new Error('INVALID_SALE_OPERATION');
    const result = { id: op.entity_id, synced: true };
    const outcome = await createSaleTransaction(user.id, parsedSale.data, operationRecord(deviceId, op, result));
    return { status: 'applied', result: { ...result, duplicate: outcome.duplicate }, duplicate: outcome.duplicate };
  }

  if (op.entity_type === 'customer_payment') {
    const p=op.payload; const paymentId=String(p.id??op.entity_id); const customerId=String(p.customer_id??'');
    const amount=Number(p.amount); const method=String(p.payment_method??'cash');
    const note=p.note?String(p.note):null; const paidAt=p.paid_at?String(p.paid_at):new Date().toISOString();
    if(paymentId!==op.entity_id||String(p.business_id??op.business_id)!==op.business_id||!z.string().uuid().safeParse(customerId).success||!Number.isFinite(amount)||amount<=0||!['cash','mobile_money','card','bank_transfer','other'].includes(method))throw new Error('INVALID_CUSTOMER_PAYMENT');
    const [customer]=await db.select().from(customers).where(and(eq(customers.id,customerId),eq(customers.businessId,op.business_id))).limit(1);
    if(!customer)throw new Error('CUSTOMER_NOT_FOUND');
    if(Number(customer.balanceDue)<amount)throw new Error('PAYMENT_EXCEEDS_DEBT');
    const result={id:paymentId,customer_id:customerId,synced:true};
    await db.batch([
      db.insert(customerPayments).values({id:paymentId,businessId:op.business_id,customerId,amount,paymentMethod:method,note,paidAt,createdBy:user.id}),
      db.update(customers).set({balanceDue:sql`${customers.balanceDue} - ${amount}`}).where(and(eq(customers.id,customerId),eq(customers.businessId,op.business_id))),
      db.insert(syncOperations).values(operationRecord(deviceId,op,result)),
    ]);
    return {status:'applied',result,duplicate:false};
  }

  if (op.entity_type === 'expense') {
    const p=op.payload; const expenseId=String(p.id??op.entity_id);
    const category=String(p.category??'').trim(); const description=String(p.description??'').trim();
    const amount=Number(p.amount); const currencyCode=String(p.currency_code??'');
    if(expenseId!==op.entity_id||String(p.business_id??op.business_id)!==op.business_id||!category||!description||!Number.isFinite(amount)||amount<=0||!/^[A-Z]{3}$/.test(currencyCode))throw new Error('INVALID_EXPENSE_PAYLOAD');
    const paidAt=p.paid_at?String(p.paid_at):new Date().toISOString();
    const createdAt=p.created_at?String(p.created_at):new Date().toISOString();
    const [existing]=await db.select({id:expenses.id,businessId:expenses.businessId}).from(expenses).where(eq(expenses.id,expenseId)).limit(1);
    if(existing&&existing.businessId!==op.business_id)throw new Error('EXPENSE_BUSINESS_MISMATCH');
    const result={id:expenseId,synced:true};
    const write=existing?db.update(expenses).set({category,description,amount,currencyCode,paidAt,paymentMethod:p.payment_method?String(p.payment_method):null}).where(eq(expenses.id,expenseId)):db.insert(expenses).values({id:expenseId,businessId:op.business_id,category,description,amount,currencyCode,paidAt,paymentMethod:p.payment_method?String(p.payment_method):null,createdBy:user.id,createdAt});
    await db.batch([write,db.insert(syncOperations).values(operationRecord(deviceId,op,result))]);
    return {status:'applied',result,duplicate:false};
  }

  if (op.entity_type === 'purchase') {
    const p = op.payload;
    const purchaseId = String(p.id ?? op.entity_id);
    const supplierId = p.supplier_id ? String(p.supplier_id) : null;
    const warehouseId = String(p.warehouse_id ?? '');
    const purchaseNumber = String(p.purchase_number ?? '').trim();
    const currencyCode = String(p.currency_code ?? '');
    const status = String(p.status ?? 'received');
    const items = Array.isArray(p.items) ? p.items : [];
    if (purchaseId !== op.entity_id || String(p.business_id ?? op.business_id) !== op.business_id ||
        !purchaseNumber || !/^[A-Z]{3}$/.test(currencyCode) || status !== 'received' || items.length < 1 || items.length > 100) {
      throw new Error('INVALID_PURCHASE_PAYLOAD');
    }
    const [existing] = await db.select({id:purchases.id,businessId:purchases.businessId}).from(purchases).where(eq(purchases.id,purchaseId)).limit(1);
    if (existing) {
      if (existing.businessId !== op.business_id) throw new Error('PURCHASE_BUSINESS_MISMATCH');
      const result = {id:purchaseId,synced:true,duplicate:true};
      await db.insert(syncOperations).values(operationRecord(deviceId,op,result));
      return {status:'applied',result,duplicate:true};
    }
    const [warehouse] = await db.select({id:warehouses.id}).from(warehouses).where(and(eq(warehouses.id,warehouseId),eq(warehouses.businessId,op.business_id))).limit(1);
    if (!warehouse) throw new Error('WAREHOUSE_NOT_FOUND');
    if (supplierId) {
      const [supplier] = await db.select({id:suppliers.id}).from(suppliers).where(and(eq(suppliers.id,supplierId),eq(suppliers.businessId,op.business_id))).limit(1);
      if (!supplier) throw new Error('SUPPLIER_NOT_FOUND');
    }
    let total = 0;
    const parsedItems = [];
    for (const raw of items) {
      const item = raw as Record<string,unknown>;
      const productId = String(item.product_id ?? '');
      const quantity = Number(item.quantity);
      const unitCost = Number(item.unit_cost);
      if (!productId || !Number.isFinite(quantity) || quantity <= 0 || !Number.isFinite(unitCost) || unitCost < 0) throw new Error('INVALID_PURCHASE_ITEM');
      const [product] = await db.select({id:products.id,name:products.name}).from(products).where(and(eq(products.id,productId),eq(products.businessId,op.business_id))).limit(1);
      if (!product) throw new Error('PRODUCT_NOT_FOUND');
      const lineTotal = Math.round(quantity * unitCost * 100) / 100;
      total += lineTotal;
      parsedItems.push({id:String(item.id ?? crypto.randomUUID()),productId,productName:String(item.product_name_snapshot ?? product.name),quantity,unitCost,lineTotal});
    }
    total = Math.round(total * 100) / 100;
    const now = new Date().toISOString();
    const result = {id:purchaseId,synced:true};
    const queries: [any, ...any[]] = [
      db.insert(purchases).values({id:purchaseId,businessId:op.business_id,supplierId,warehouseId,purchaseNumber,status:'received',currencyCode,total,orderedAt:p.ordered_at?String(p.ordered_at):now,receivedAt:p.received_at?String(p.received_at):now,createdAt:p.created_at?String(p.created_at):now}),
    ...parsedItems.map(i=>db.insert(purchaseItems).values({id:i.id,purchaseId,productId:i.productId,productNameSnapshot:i.productName,quantity:i.quantity,unitCost:i.unitCost,lineTotal:i.lineTotal})),
    ...parsedItems.map(i=>db.insert(stockMovements).values({id:crypto.randomUUID(),businessId:op.business_id,warehouseId,productId:i.productId,movementType:'purchase',quantityDelta:i.quantity,unitCost:i.unitCost,sourceType:'purchase',sourceId:purchaseId,note:'Réception '+purchaseNumber,actorUserId:user.id,occurredAt:now,createdAt:now})),
    ...parsedItems.map(i=>db.insert(stockLevels).values({id:crypto.randomUUID(),businessId:op.business_id,warehouseId,productId:i.productId,quantity:i.quantity,updatedAt:now}).onConflictDoUpdate({target:[stockLevels.warehouseId,stockLevels.productId],set:{quantity:sql`${stockLevels.quantity} + ${i.quantity}`,updatedAt:now}})),
    db.insert(syncOperations).values(operationRecord(deviceId,op,result)),
  ];
  await db.batch(queries);
  return {status:'applied',result,duplicate:false};
  }

  if (op.entity_type === 'customer') {
    const p = op.payload;
    const customerId = String(p.id ?? op.entity_id);
    if (customerId !== op.entity_id || String(p.business_id ?? op.business_id) !== op.business_id || !String(p.name ?? '').trim()) throw new Error('INVALID_CUSTOMER_PAYLOAD');
    const values = { name: String(p.name).trim(), phone: p.phone ? String(p.phone).trim() : null, email: p.email ? String(p.email).trim() : null, address: p.address ? String(p.address).trim() : null, notes: p.notes ? String(p.notes).trim() : null, updatedAt: p.updated_at ? String(p.updated_at) : new Date().toISOString() };
    const [current] = await db.select({ id: customers.id, businessId: customers.businessId }).from(customers).where(eq(customers.id, customerId)).limit(1);
    if (current && current.businessId !== op.business_id) throw new Error('CUSTOMER_BUSINESS_MISMATCH');
    const result = { id: customerId, synced: true };
    const write = current
      ? db.update(customers).set(values).where(eq(customers.id, customerId))
      : db.insert(customers).values({ id: customerId, businessId: op.business_id, ...values, balanceDue: Number(p.balance_due ?? 0), createdAt: p.created_at ? String(p.created_at) : new Date().toISOString() });
    await db.batch([write, db.insert(syncOperations).values(operationRecord(deviceId, op, result))]);
    return { status: 'applied', result, duplicate: false };
  }

  if (op.entity_type === 'supplier') {
    const p = op.payload;
    const supplierId = String(p.id ?? op.entity_id);
    if (supplierId !== op.entity_id || String(p.business_id ?? op.business_id) !== op.business_id || !String(p.name ?? '').trim()) throw new Error('INVALID_SUPPLIER_PAYLOAD');
    const values = { name: String(p.name).trim(), phone: p.phone ? String(p.phone).trim() : null, email: p.email ? String(p.email).trim() : null, address: p.address ? String(p.address).trim() : null, notes: p.notes ? String(p.notes).trim() : null, updatedAt: p.updated_at ? String(p.updated_at) : new Date().toISOString() };
    const [current] = await db.select({ id: suppliers.id, businessId: suppliers.businessId }).from(suppliers).where(eq(suppliers.id, supplierId)).limit(1);
    if (current && current.businessId !== op.business_id) throw new Error('SUPPLIER_BUSINESS_MISMATCH');
    const result = { id: supplierId, synced: true };
    const write = current
      ? db.update(suppliers).set(values).where(eq(suppliers.id, supplierId))
      : db.insert(suppliers).values({ id: supplierId, businessId: op.business_id, ...values, createdAt: p.created_at ? String(p.created_at) : new Date().toISOString() });
    await db.batch([write, db.insert(syncOperations).values(operationRecord(deviceId, op, result))]);
    return { status: 'applied', result, duplicate: false };
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
});
