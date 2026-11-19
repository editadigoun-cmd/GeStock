import { and, eq, inArray, sql } from 'drizzle-orm';
import { z } from 'zod';
import { db } from './db.js';
import { businesses, customers, products, sales, saleItems, salePayments, stockLevels, stockMovements, warehouses, syncOperations } from '../schema.js';
import { calculateSaleTotals } from './sale-math.js';

export const saleInputSchema = z.object({
  id: z.string().uuid(),
  business_id: z.string().uuid(),
  warehouse_id: z.string().uuid(),
  sale_number: z.string().trim().min(1).max(80),
  currency_code: z.string().regex(/^[A-Z]{3}$/),
  customer_id: z.string().uuid().optional().nullable(),
  sold_at: z.string().datetime({ offset: true }).optional(),
  payment_method: z.enum(['cash', 'mobile_money', 'card', 'bank_transfer', 'other']),
  payment_amount: z.number().nonnegative().optional(),
  items: z.array(z.object({
    product_id: z.string().uuid(),
    product_name_snapshot: z.string().max(180).optional(),
    quantity: z.number().finite().positive(),
    unit_price: z.number().finite().nonnegative(),
    discount_amount: z.number().finite().nonnegative().optional().default(0),
    tax_amount: z.number().finite().nonnegative().optional().default(0),
  })).min(1).max(20),
});

export type SaleInput = z.infer<typeof saleInputSchema>;
export type SyncSaleRecord = typeof syncOperations.$inferInsert;

export async function createSaleTransaction(userId: string, input: SaleInput, syncRecord?: SyncSaleRecord) {
  const [business] = await db.select({ id: businesses.id }).from(businesses).where(eq(businesses.id, input.business_id)).limit(1);
  if (!business) throw new Error('BUSINESS_NOT_FOUND');
  const [warehouse] = await db.select({ id: warehouses.id }).from(warehouses)
    .where(and(eq(warehouses.id, input.warehouse_id), eq(warehouses.businessId, input.business_id))).limit(1);
  if (!warehouse) throw new Error('WAREHOUSE_NOT_FOUND');

  const [existing] = await db.select({ id: sales.id, businessId: sales.businessId, saleNumber: sales.saleNumber })
    .from(sales).where(eq(sales.id, input.id)).limit(1);
  if (existing) {
    if (existing.businessId !== input.business_id) throw new Error('SALE_ID_CONFLICT');
    if (syncRecord) await db.insert(syncOperations).values({ ...syncRecord, result: { id: input.id, synced: true, duplicate: true } });
    return { id: input.id, duplicate: true, total: 0, amount_paid: 0 };
  }
  const [sameNumber] = await db.select({ id: sales.id }).from(sales)
    .where(and(eq(sales.businessId, input.business_id), eq(sales.saleNumber, input.sale_number))).limit(1);
  if (sameNumber) throw new Error('SALE_NUMBER_EXISTS');

  if (input.customer_id) {
    const [customer] = await db.select({ id: customers.id }).from(customers)
      .where(and(eq(customers.id, input.customer_id), eq(customers.businessId, input.business_id))).limit(1);
    if (!customer) throw new Error('CUSTOMER_NOT_FOUND');
  }

  const productIds = [...new Set(input.items.map((item) => item.product_id))];
  const productRows = await db.select().from(products).where(and(eq(products.businessId, input.business_id), inArray(products.id, productIds)));
  const productMap = new Map(productRows.map((product) => [product.id, product]));
  if (productMap.size !== productIds.length) throw new Error('PRODUCT_NOT_FOUND');

  const stockRows = await db.select().from(stockLevels).where(and(
    eq(stockLevels.businessId, input.business_id),
    eq(stockLevels.warehouseId, input.warehouse_id),
    inArray(stockLevels.productId, productIds),
  ));
  const stockMap = new Map(stockRows.map((row) => [row.productId, Number(row.quantity)]));
  const quantities = new Map<string, number>();
  for (const item of input.items) quantities.set(item.product_id, (quantities.get(item.product_id) ?? 0) + item.quantity);

  for (const [productId, quantity] of quantities) {
    const product = productMap.get(productId)!;
    if (product.isActive === 0) throw new Error('PRODUCT_INACTIVE');
    if (product.trackStock !== 0 && (stockMap.get(productId) ?? 0) < quantity) {
      throw new Error('INSUFFICIENT_STOCK:' + product.name);
    }
  }

  const totals = calculateSaleTotals(input.items);
  const paymentAmount = input.payment_amount ?? totals.total;
  if (!Number.isFinite(paymentAmount) || paymentAmount < 0) throw new Error('INVALID_PAYMENT_AMOUNT');
  if (input.payment_method === 'cash' || input.payment_method === 'other') {
    if (paymentAmount < totals.total) throw new Error('PAYMENT_INCOMPLETE');
  } else if (paymentAmount !== totals.total) {
    throw new Error('PAYMENT_AMOUNT_MISMATCH');
  }
  const pending = ['mobile_money', 'card', 'bank_transfer'].includes(input.payment_method);
  const amountPaid = pending ? 0 : Math.min(paymentAmount, totals.total);
  const now = new Date().toISOString();
  const soldAt = input.sold_at ?? now;

  const queries: any[] = [
    db.insert(sales).values({
      id: input.id, businessId: input.business_id, locationId: null, customerId: input.customer_id ?? null,
      saleNumber: input.sale_number, status: 'completed', currencyCode: input.currency_code,
      subtotal: totals.subtotal, discountTotal: totals.discount_total, taxTotal: totals.tax_total,
      total: totals.total, amountPaid, soldAt, createdBy: userId, deviceOperationId: syncRecord?.operationKey ?? null, createdAt: now,
    }),
  ];
  input.items.forEach((item, index) => {
    const product = productMap.get(item.product_id)!;
    queries.push(db.insert(saleItems).values({
      id: crypto.randomUUID(), saleId: input.id, productId: item.product_id,
      productNameSnapshot: item.product_name_snapshot?.trim() || product.name,
      quantity: item.quantity, unitPrice: item.unit_price,
      discountAmount: item.discount_amount ?? 0, taxAmount: item.tax_amount ?? 0,
      lineTotal: totals.lines[index].line_total,
    }));
  });
  queries.push(db.insert(salePayments).values({
    id: crypto.randomUUID(), saleId: input.id, paymentMethod: input.payment_method,
    amount: paymentAmount, status: pending ? 'pending' : 'confirmed',
    paidAt: pending ? null : now, createdAt: now,
  }));
  for (const [productId, quantity] of quantities) {
    const product = productMap.get(productId)!;
    if (product.trackStock === 0) continue;
    queries.push(db.insert(stockMovements).values({
      id: crypto.randomUUID(), businessId: input.business_id, warehouseId: input.warehouse_id,
      productId, movementType: 'sale', quantityDelta: -quantity,
      sourceType: 'sale', sourceId: input.id, actorUserId: userId, occurredAt: soldAt, createdAt: now,
    }));
    queries.push(db.insert(stockLevels).values({
      id: crypto.randomUUID(), businessId: input.business_id, warehouseId: input.warehouse_id,
      productId, quantity: -quantity, updatedAt: now,
    }).onConflictDoUpdate({
      target: [stockLevels.warehouseId, stockLevels.productId],
      set: { quantity: sql`${stockLevels.quantity} - ${quantity}`, updatedAt: now },
    }));
  }
  if (syncRecord) queries.push(db.insert(syncOperations).values({ ...syncRecord, result: { id: input.id, synced: true, duplicate: false } }));
  await db.batch(queries as Parameters<typeof db.batch>[0]);
  return { id: input.id, duplicate: false, total: totals.total, amount_paid: amountPaid, change_due: Math.max(0, paymentAmount - totals.total), payment_status: pending ? 'pending' : 'confirmed' };
}
