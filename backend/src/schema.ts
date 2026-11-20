import { sqliteTable, text, integer, real, uniqueIndex, index } from 'drizzle-orm/sqlite-core';
import { sql } from 'drizzle-orm';

const id = () => text('id').primaryKey().$defaultFn(() => crypto.randomUUID());
const json = (name: string) => text(name, { mode: 'json' });
const timestamp = (name: string) => text(name).notNull().default(sql`CURRENT_TIMESTAMP`);

export const appUsers = sqliteTable('app_users', {
  id: id(), authSubject: text('auth_subject').unique(), email: text('email'), displayName: text('display_name'),
  passwordHash: text('password_hash'), emailVerified: integer('email_verified').notNull().default(0), status: text('status').notNull().default('active'),
  phone: text('phone'), preferredLocale: text('preferred_locale').notNull().default('fr'),
  createdAt: text('created_at'), updatedAt: text('updated_at'),
});
export const organizations = sqliteTable('organizations', {
  id: id(), name: text('name').notNull(), ownerUserId: text('owner_user_id').notNull(), status: text('status').notNull().default('active'),
  createdAt: text('created_at'), updatedAt: text('updated_at'),
});
export const organizationMemberships = sqliteTable('organization_memberships', {
  id: id(), organizationId: text('organization_id').notNull(), userId: text('user_id').notNull(),
  role: text('role').notNull().default('member'), status: text('status').notNull().default('active'), createdAt: text('created_at'),
}, t => ({ orgUser: uniqueIndex('organization_memberships_org_user_uq').on(t.organizationId, t.userId) }));
export const businesses = sqliteTable('businesses', {
  id: id(), organizationId: text('organization_id').notNull(), name: text('name').notNull(),
  businessType: text('business_type').notNull().default('general'), legalName: text('legal_name'), taxId: text('tax_id'),
  countryCode: text('country_code').notNull().default('BJ'), currencyCode: text('currency_code').notNull().default('XOF'),
  timezone: text('timezone').notNull().default('Africa/Porto-Novo'), settings: json('settings').notNull().default({}),
  status: text('status').notNull().default('active'), createdAt: text('created_at'), updatedAt: text('updated_at'),
}, t => ({ orgIdx: index('businesses_org_idx').on(t.organizationId) }));
export const businessMemberships = sqliteTable('business_memberships', {
  id: id(), businessId: text('business_id').notNull(), userId: text('user_id').notNull(),
  role: text('role').notNull().default('staff'), permissions: json('permissions').notNull().default({}),
  status: text('status').notNull().default('active'), createdAt: text('created_at'),
}, t => ({
  userIdx: index('business_memberships_user_idx').on(t.userId, t.status),
  businessUser: uniqueIndex('business_memberships_business_user_uq').on(t.businessId, t.userId),
}));
export const businessLocations = sqliteTable('business_locations', {
  id: id(), businessId: text('business_id').notNull(), name: text('name').notNull(),
  address: text('address'), phone: text('phone'), isDefault: integer('is_default').notNull().default(0), createdAt: timestamp('created_at'),
}, t => ({ businessName: uniqueIndex('business_locations_business_id_name_key').on(t.businessId, t.name) }));
export const syncDevices = sqliteTable('sync_devices', {
  id: id(), userId: text('user_id').notNull(), deviceKey: text('device_key').notNull(),
  platform: text('platform').notNull(), lastSeenAt: text('last_seen_at'), createdAt: timestamp('created_at'),
}, t => ({ userDevice: uniqueIndex('sync_devices_user_device').on(t.userId, t.deviceKey) }));
export const productCategories = sqliteTable('product_categories', {
  id: id(), businessId: text('business_id').notNull(), parentId: text('parent_id'), name: text('name').notNull(), createdAt: timestamp('created_at'),
}, t => ({ businessName: uniqueIndex('product_categories_business_id_name_key').on(t.businessId, t.name) }));
export const products = sqliteTable('products', {
  id: id(), businessId: text('business_id').notNull(), categoryId: text('category_id'),
  name: text('name').notNull(), description: text('description'), sku: text('sku'), barcode: text('barcode'),
  unit: text('unit').notNull().default('unité'), purchasePrice: real('purchase_price').notNull().default(0),
  salePrice: real('sale_price').notNull().default(0), taxRate: real('tax_rate').notNull().default(0),
  trackStock: integer('track_stock').notNull().default(1), isActive: integer('is_active').notNull().default(1),
  metadata: json('metadata').notNull().default({}), createdAt: timestamp('created_at'), updatedAt: timestamp('updated_at'),
}, t => ({
  businessIdx: index('idx_products_business').on(t.businessId),
  barcodeIdx: index('idx_products_barcode').on(t.barcode),
  businessName: index('products_business_name_idx').on(t.businessId, t.name),
  businessSku: uniqueIndex('products_business_sku_uq').on(t.businessId, t.sku),
}));
export const warehouses = sqliteTable('warehouses', {
  id: id(), businessId: text('business_id').notNull(), locationId: text('location_id'),
  name: text('name').notNull(), isDefault: integer('is_default').notNull().default(0), createdAt: timestamp('created_at'),
}, t => ({ businessName: uniqueIndex('warehouses_business_name_uq').on(t.businessId, t.name) }));
export const stockLevels = sqliteTable('stock_levels', {
  id: id(), businessId: text('business_id').notNull(), warehouseId: text('warehouse_id').notNull(),
  productId: text('product_id').notNull(), quantity: real('quantity').notNull().default(0), updatedAt: timestamp('updated_at'),
}, t => ({
  warehouseProduct: uniqueIndex('stock_levels_warehouse_product').on(t.warehouseId, t.productId),
  productIdx: index('idx_stock_levels_product').on(t.productId),
}));
export const stockMovements = sqliteTable('stock_movements', {
  id: id(), businessId: text('business_id').notNull(), warehouseId: text('warehouse_id').notNull(),
  productId: text('product_id').notNull(), movementType: text('movement_type').notNull(),
  quantityDelta: real('quantity_delta').notNull(), unitCost: real('unit_cost'), sourceType: text('source_type'),
  sourceId: text('source_id'), note: text('note'), actorUserId: text('actor_user_id'),
  occurredAt: timestamp('occurred_at'), createdAt: timestamp('created_at'),
}, t => ({
  businessTime: index('idx_stock_movements_business_time').on(t.businessId, t.occurredAt),
  productIdx: index('idx_stock_movements_product').on(t.productId),
}));
export const stockTransfers = sqliteTable('stock_transfers', {
  id: id(), businessId: text('business_id').notNull(), fromWarehouseId: text('from_warehouse_id').notNull(),
  toWarehouseId: text('to_warehouse_id').notNull(), transferNumber: text('transfer_number').notNull(),
  status: text('status').notNull().default('completed'), note: text('note'), createdBy: text('created_by'),
  transferredAt: text('transferred_at').notNull(), createdAt: timestamp('created_at'),
}, t => ({
  businessNumber: uniqueIndex('stock_transfers_business_number_uq').on(t.businessId,t.transferNumber),
  businessTime: index('stock_transfers_business_time_idx').on(t.businessId,t.transferredAt),
}));
export const stockTransferItems = sqliteTable('stock_transfer_items', {
  id: id(), transferId: text('transfer_id').notNull(), productId: text('product_id').notNull(),
  productNameSnapshot: text('product_name_snapshot').notNull(), quantity: real('quantity').notNull(),
}, t => ({ transferIdx: index('stock_transfer_items_transfer_idx').on(t.transferId) }));
export const customers = sqliteTable('customers', {
  id: id(), businessId: text('business_id').notNull(), name: text('name').notNull(),
  phone: text('phone'), email: text('email'), address: text('address'), notes: text('notes'),
  balanceDue: real('balance_due').notNull().default(0), createdAt: timestamp('created_at'), updatedAt: timestamp('updated_at'),
});
export const suppliers = sqliteTable('suppliers', {
  id: id(), businessId: text('business_id').notNull(), name: text('name').notNull(),
  phone: text('phone'), email: text('email'), address: text('address'), notes: text('notes'),
  createdAt: timestamp('created_at'), updatedAt: timestamp('updated_at'),
});
export const purchases = sqliteTable('purchases', {
  id: id(), businessId: text('business_id').notNull(), supplierId: text('supplier_id'), warehouseId: text('warehouse_id'),
  purchaseNumber: text('purchase_number').notNull(), status: text('status').notNull().default('received'),
  currencyCode: text('currency_code').notNull(), total: real('total').notNull().default(0),
  orderedAt: text('ordered_at'), receivedAt: text('received_at'), createdAt: timestamp('created_at'),
}, t => ({
  businessNumber: uniqueIndex('purchases_business_id_purchase_number_key').on(t.businessId, t.purchaseNumber),
  businessTime: index('purchases_business_time_idx').on(t.businessId, t.createdAt),
}));
export const purchaseItems = sqliteTable('purchase_items', {
  id: id(), purchaseId: text('purchase_id').notNull(), productId: text('product_id'),
  productNameSnapshot: text('product_name_snapshot').notNull(), quantity: real('quantity').notNull(),
  unitCost: real('unit_cost').notNull(), lineTotal: real('line_total').notNull(),
});
export const sales = sqliteTable('sales', {
  id: id(), businessId: text('business_id').notNull(), locationId: text('location_id'), customerId: text('customer_id'),
  saleNumber: text('sale_number').notNull(), status: text('status').notNull().default('completed'),
  currencyCode: text('currency_code').notNull(), subtotal: real('subtotal').notNull().default(0),
  discountTotal: real('discount_total').notNull().default(0), taxTotal: real('tax_total').notNull().default(0),
  total: real('total').notNull().default(0), amountPaid: real('amount_paid').notNull().default(0),
  soldAt: timestamp('sold_at'), createdBy: text('created_by'), deviceOperationId: text('device_operation_id'),
  createdAt: timestamp('created_at'),
}, t => ({
  businessNumber: uniqueIndex('sales_business_id_sale_number_key').on(t.businessId, t.saleNumber),
  businessSold: index('sales_business_sold_idx').on(t.businessId, t.soldAt),
}));
export const saleItems = sqliteTable('sale_items', {
  id: id(), saleId: text('sale_id').notNull(), productId: text('product_id'),
  productNameSnapshot: text('product_name_snapshot').notNull(), quantity: real('quantity').notNull(),
  unitPrice: real('unit_price').notNull(), discountAmount: real('discount_amount').notNull().default(0),
  taxAmount: real('tax_amount').notNull().default(0), lineTotal: real('line_total').notNull(),
});
export const customerPayments = sqliteTable('customer_payments', {
  id: id(), businessId: text('business_id').notNull(), customerId: text('customer_id').notNull(), amount: real('amount').notNull(), paymentMethod: text('payment_method').notNull(), note: text('note'), paidAt: text('paid_at').notNull(), createdBy: text('created_by'), createdAt: timestamp('created_at'),
}, t => ({ businessCustomerTime: index('customer_payments_business_customer_time_idx').on(t.businessId, t.customerId, t.paidAt) }));
export const salePayments = sqliteTable('sale_payments', {
  id: id(), saleId: text('sale_id').notNull(), paymentMethod: text('payment_method').notNull(),
  amount: real('amount').notNull(), status: text('status').notNull().default('confirmed'),
  providerReference: text('provider_reference'), paidAt: text('paid_at'), createdAt: timestamp('created_at'),
});
export const saleReturns = sqliteTable('sale_returns', {
  id: id(), businessId: text('business_id').notNull(), saleId: text('sale_id').notNull(),
  returnNumber: text('return_number').notNull(), reason: text('reason').notNull(),
  refundMethod: text('refund_method').notNull(), refundAmount: real('refund_amount').notNull(),
  status: text('status').notNull().default('completed'), returnedAt: text('returned_at').notNull(),
  createdBy: text('created_by'), createdAt: timestamp('created_at'),
}, t => ({businessNumber: uniqueIndex('sale_returns_business_number_uq').on(t.businessId,t.returnNumber), saleIdx:index('sale_returns_sale_idx').on(t.saleId)}));
export const saleReturnItems = sqliteTable('sale_return_items', {
  id: id(), returnId: text('return_id').notNull(), saleItemId: text('sale_item_id').notNull(),
  productId: text('product_id'), productNameSnapshot: text('product_name_snapshot').notNull(),
  quantity: real('quantity').notNull(), unitPrice: real('unit_price').notNull(), refundAmount: real('refund_amount').notNull(),
});
export const cashRegisters = sqliteTable('cash_registers', {
  id: id(), businessId: text('business_id').notNull(), locationId: text('location_id'),
  name: text('name').notNull(), isActive: integer('is_active').notNull().default(1), createdAt: timestamp('created_at'),
}, t => ({ businessName: uniqueIndex('cash_registers_business_id_name_key').on(t.businessId, t.name) }));
export const cashSessions = sqliteTable('cash_sessions', {
  id: id(), businessId: text('business_id').notNull(), registerId: text('register_id').notNull(),
  openedBy: text('opened_by'), closedBy: text('closed_by'), openingAmount: real('opening_amount').notNull().default(0),
  closingAmount: real('closing_amount'), expectedAmount: real('expected_amount'), openedAt: timestamp('opened_at'),
  closedAt: text('closed_at'), status: text('status').notNull().default('open'),
});
export const expenses = sqliteTable('expenses', {
  id: id(), businessId: text('business_id').notNull(), category: text('category').notNull(),
  description: text('description').notNull(), amount: real('amount').notNull(), currencyCode: text('currency_code').notNull(),
  paidAt: timestamp('paid_at'), paymentMethod: text('payment_method'), createdBy: text('created_by'), createdAt: timestamp('created_at'),
});
export const auditLogs = sqliteTable('audit_logs', {
  id: id(), businessId: text('business_id'), actorUserId: text('actor_user_id'),
  action: text('action').notNull(), entityType: text('entity_type').notNull(), entityId: text('entity_id'),
  beforeData: json('before_data'), afterData: json('after_data'), createdAt: timestamp('created_at'),
});
export const syncOperations = sqliteTable('sync_operations', {
  id: id(), businessId: text('business_id').notNull(), deviceId: text('device_id').notNull(),
  operationKey: text('operation_key').notNull().unique(), entityType: text('entity_type').notNull(),
  entityId: text('entity_id'), operationType: text('operation_type').notNull(), payload: json('payload').notNull(),
  status: text('status').notNull().default('queued'), result: json('result'), createdAt: timestamp('created_at'),
  processedAt: text('processed_at'),
}, t => ({ statusIdx: index('idx_sync_ops_status').on(t.status, t.createdAt) }));
