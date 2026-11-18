import { pgTable, uuid, text, numeric, boolean, jsonb, timestamp } from 'drizzle-orm/pg-core';
export const appUsers=pgTable('app_users',{id:uuid('id').defaultRandom().primaryKey(),authSubject:text('auth_subject').unique(),email:text('email'),displayName:text('display_name')});
export const businessMemberships=pgTable('business_memberships',{id:uuid('id').defaultRandom().primaryKey(),businessId:uuid('business_id').notNull(),userId:uuid('user_id').notNull(),role:text('role').notNull().default('staff'),permissions:jsonb('permissions').notNull().default({}),status:text('status').notNull().default('active')});
export const syncDevices=pgTable('sync_devices',{id:uuid('id').defaultRandom().primaryKey(),userId:uuid('user_id').notNull(),deviceKey:text('device_key').notNull(),platform:text('platform').notNull(),lastSeenAt:timestamp('last_seen_at',{withTimezone:true}),createdAt:timestamp('created_at',{withTimezone:true}).notNull().defaultNow()});
export const products=pgTable('products',{
 id:uuid('id').defaultRandom().primaryKey(),businessId:uuid('business_id').notNull(),name:text('name').notNull(),sku:text('sku'),barcode:text('barcode'),unit:text('unit').notNull().default('unité'),
 purchasePrice:numeric('purchase_price',{precision:20,scale:4}).notNull().default('0'),salePrice:numeric('sale_price',{precision:20,scale:4}).notNull().default('0'),taxRate:numeric('tax_rate',{precision:7,scale:4}).notNull().default('0'),
 trackStock:boolean('track_stock').notNull().default(true),isActive:boolean('is_active').notNull().default(true),metadata:jsonb('metadata').notNull().default({}),
 createdAt:timestamp('created_at',{withTimezone:true}).notNull().defaultNow(),updatedAt:timestamp('updated_at',{withTimezone:true}).notNull().defaultNow(),
});
export const syncOperations=pgTable('sync_operations',{
 id:uuid('id').defaultRandom().primaryKey(),businessId:uuid('business_id').notNull(),deviceId:uuid('device_id').notNull(),operationKey:uuid('operation_key').notNull(),
 entityType:text('entity_type').notNull(),entityId:uuid('entity_id'),operationType:text('operation_type').notNull(),payload:jsonb('payload').notNull(),
 status:text('status').notNull().default('queued'),result:jsonb('result'),createdAt:timestamp('created_at',{withTimezone:true}).notNull().defaultNow(),processedAt:timestamp('processed_at',{withTimezone:true}),
});

export const organizations=pgTable('organizations',{id:uuid('id').defaultRandom().primaryKey(),name:text('name').notNull(),ownerUserId:uuid('owner_user_id').notNull(),status:text('status').notNull().default('active')});
export const organizationMemberships=pgTable('organization_memberships',{id:uuid('id').defaultRandom().primaryKey(),organizationId:uuid('organization_id').notNull(),userId:uuid('user_id').notNull(),role:text('role').notNull().default('member'),status:text('status').notNull().default('active')});
export const businesses=pgTable('businesses',{id:uuid('id').defaultRandom().primaryKey(),organizationId:uuid('organization_id').notNull(),name:text('name').notNull(),businessType:text('business_type').notNull().default('general'),countryCode:text('country_code').notNull().default('BJ'),currencyCode:text('currency_code').notNull().default('XOF'),timezone:text('timezone').notNull().default('Africa/Porto-Novo'),settings:jsonb('settings').notNull().default({}),status:text('status').notNull().default('active')});
