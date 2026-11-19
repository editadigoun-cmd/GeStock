-- GeStock D1 initial schema
-- Database: gestock-db (Cloudflare D1)
CREATE TABLE IF NOT EXISTS app_users (id TEXT PRIMARY KEY, auth_subject TEXT UNIQUE, email TEXT, display_name TEXT);
CREATE TABLE IF NOT EXISTS organizations (id TEXT PRIMARY KEY, name TEXT NOT NULL, owner_user_id TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'active');
CREATE TABLE IF NOT EXISTS organization_memberships (id TEXT PRIMARY KEY, organization_id TEXT NOT NULL, user_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'member', status TEXT NOT NULL DEFAULT 'active');
CREATE TABLE IF NOT EXISTS businesses (id TEXT PRIMARY KEY, organization_id TEXT NOT NULL, name TEXT NOT NULL, business_type TEXT NOT NULL DEFAULT 'general', country_code TEXT NOT NULL DEFAULT 'BJ', currency_code TEXT NOT NULL DEFAULT 'XOF', timezone TEXT NOT NULL DEFAULT 'Africa/Porto-Novo', settings TEXT NOT NULL DEFAULT '{}', status TEXT NOT NULL DEFAULT 'active');
CREATE TABLE IF NOT EXISTS business_memberships (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, user_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'staff', permissions TEXT NOT NULL DEFAULT '{}', status TEXT NOT NULL DEFAULT 'active');
CREATE TABLE IF NOT EXISTS sync_devices (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, device_key TEXT NOT NULL, platform TEXT NOT NULL, last_seen_at TEXT, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS products (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, name TEXT NOT NULL, sku TEXT, barcode TEXT, unit TEXT NOT NULL DEFAULT 'unité', purchase_price NUMERIC NOT NULL DEFAULT 0, sale_price NUMERIC NOT NULL DEFAULT 0, tax_rate NUMERIC NOT NULL DEFAULT 0, track_stock INTEGER NOT NULL DEFAULT 1, is_active INTEGER NOT NULL DEFAULT 1, metadata TEXT NOT NULL DEFAULT '{}', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS warehouses (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, location_id TEXT, name TEXT NOT NULL, is_default INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS stock_levels (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, warehouse_id TEXT NOT NULL, product_id TEXT NOT NULL, quantity NUMERIC NOT NULL DEFAULT 0, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(warehouse_id, product_id));
CREATE TABLE IF NOT EXISTS stock_movements (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, warehouse_id TEXT NOT NULL, product_id TEXT NOT NULL, movement_type TEXT NOT NULL, quantity_delta NUMERIC NOT NULL, unit_cost NUMERIC, source_type TEXT, source_id TEXT, note TEXT, actor_user_id TEXT, occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS sync_operations (id TEXT PRIMARY KEY, business_id TEXT NOT NULL, device_id TEXT NOT NULL, operation_key TEXT NOT NULL UNIQUE, entity_type TEXT NOT NULL, entity_id TEXT, operation_type TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'queued', result TEXT, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, processed_at TEXT);
CREATE UNIQUE INDEX IF NOT EXISTS sync_devices_user_device ON sync_devices(user_id, device_key);
CREATE INDEX IF NOT EXISTS idx_products_business ON products(business_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_stock_levels_product ON stock_levels(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_business_time ON stock_movements(business_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_memberships_user ON business_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_user ON organization_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_ops_status ON sync_operations(status, created_at);
