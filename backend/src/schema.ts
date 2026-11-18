import { pgTable, uuid, text, numeric, boolean, jsonb, timestamp } from 'drizzle-orm/pg-core';
export const products = pgTable('products', {
 id: uuid('id').defaultRandom().primaryKey(), businessId: uuid('business_id').notNull(),
 name: text('name').notNull(), sku: text('sku'), barcode: text('barcode'), unit: text('unit').notNull().default('unité'),
 purchasePrice: numeric('purchase_price',{precision:20,scale:4}).notNull().default('0'),
 salePrice: numeric('sale_price',{precision:20,scale:4}).notNull().default('0'),
 taxRate: numeric('tax_rate',{precision:7,scale:4}).notNull().default('0'),
 trackStock: boolean('track_stock').notNull().default(true), isActive: boolean('is_active').notNull().default(true),
 metadata: jsonb('metadata').notNull().default({}), createdAt:timestamp('created_at',{withTimezone:true}).notNull().defaultNow(),
 updatedAt:timestamp('updated_at',{withTimezone:true}).notNull().defaultNow(),
});
export const syncOperations = pgTable('sync_operations', {
 id:uuid('id').defaultRandom().primaryKey(), businessId:uuid('business_id').notNull(), deviceId:uuid('device_id').notNull(),
 operationKey:uuid('operation_key').notNull(), entityType:text('entity_type').notNull(), entityId:uuid('entity_id'),
 operationType:text('operation_type').notNull(), payload:jsonb('payload').notNull(), status:text('status').notNull().default('queued'),
 result:jsonb('result'), createdAt:timestamp('created_at',{withTimezone:true}).notNull().defaultNow(),
 processedAt:timestamp('processed_at',{withTimezone:true}),
});
