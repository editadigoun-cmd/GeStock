-- Expand the initial D1 core schema to the full domain model.
-- Existing domain tables were empty at the time of inspection; this migration is schema-only.
ALTER TABLE app_users ADD COLUMN phone TEXT;
ALTER TABLE app_users ADD COLUMN preferred_locale TEXT NOT NULL DEFAULT 'fr';
ALTER TABLE app_users ADD COLUMN created_at TEXT;
ALTER TABLE app_users ADD COLUMN updated_at TEXT;

ALTER TABLE organizations ADD COLUMN created_at TEXT;
ALTER TABLE organizations ADD COLUMN updated_at TEXT;

ALTER TABLE organization_memberships ADD COLUMN created_at TEXT;
ALTER TABLE business_memberships ADD COLUMN created_at TEXT;

ALTER TABLE businesses ADD COLUMN legal_name TEXT;
ALTER TABLE businesses ADD COLUMN tax_id TEXT;
ALTER TABLE businesses ADD COLUMN created_at TEXT;
ALTER TABLE businesses ADD COLUMN updated_at TEXT;

ALTER TABLE products ADD COLUMN category_id TEXT;
ALTER TABLE products ADD COLUMN description TEXT;

CREATE TABLE IF NOT EXISTS business_locations (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  is_default INTEGER NOT NULL DEFAULT 0 CHECK(is_default IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(business_id,name)
);

CREATE TABLE IF NOT EXISTS product_categories (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  parent_id TEXT REFERENCES product_categories(id),
  name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(business_id,name)
);

CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  balance_due REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS suppliers (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchases (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  supplier_id TEXT REFERENCES suppliers(id),
  warehouse_id TEXT REFERENCES warehouses(id),
  purchase_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'received' CHECK(status IN ('draft','ordered','received','cancelled')),
  currency_code TEXT NOT NULL,
  total REAL NOT NULL DEFAULT 0,
  ordered_at TEXT,
  received_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(business_id,purchase_number)
);

CREATE TABLE IF NOT EXISTS purchase_items (
  id TEXT PRIMARY KEY,
  purchase_id TEXT NOT NULL REFERENCES purchases(id),
  product_id TEXT REFERENCES products(id),
  product_name_snapshot TEXT NOT NULL,
  quantity REAL NOT NULL CHECK(quantity>0),
  unit_cost REAL NOT NULL CHECK(unit_cost>=0),
  line_total REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  location_id TEXT REFERENCES business_locations(id),
  customer_id TEXT REFERENCES customers(id),
  sale_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed' CHECK(status IN ('draft','completed','voided','refunded')),
  currency_code TEXT NOT NULL,
  subtotal REAL NOT NULL DEFAULT 0,
  discount_total REAL NOT NULL DEFAULT 0,
  tax_total REAL NOT NULL DEFAULT 0,
  total REAL NOT NULL DEFAULT 0,
  amount_paid REAL NOT NULL DEFAULT 0,
  sold_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by TEXT REFERENCES app_users(id),
  device_operation_id TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(business_id,sale_number)
);

CREATE TABLE IF NOT EXISTS sale_items (
  id TEXT PRIMARY KEY,
  sale_id TEXT NOT NULL REFERENCES sales(id),
  product_id TEXT REFERENCES products(id),
  product_name_snapshot TEXT NOT NULL,
  quantity REAL NOT NULL CHECK(quantity>0),
  unit_price REAL NOT NULL CHECK(unit_price>=0),
  discount_amount REAL NOT NULL DEFAULT 0,
  tax_amount REAL NOT NULL DEFAULT 0,
  line_total REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS sale_payments (
  id TEXT PRIMARY KEY,
  sale_id TEXT NOT NULL REFERENCES sales(id),
  payment_method TEXT NOT NULL CHECK(payment_method IN ('cash','mobile_money','card','bank_transfer','credit','other')),
  amount REAL NOT NULL CHECK(amount>0),
  status TEXT NOT NULL DEFAULT 'confirmed' CHECK(status IN ('pending','confirmed','failed','refunded')),
  provider_reference TEXT,
  paid_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cash_registers (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  location_id TEXT REFERENCES business_locations(id),
  name TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(business_id,name)
);

CREATE TABLE IF NOT EXISTS cash_sessions (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  register_id TEXT NOT NULL REFERENCES cash_registers(id),
  opened_by TEXT REFERENCES app_users(id),
  closed_by TEXT REFERENCES app_users(id),
  opening_amount REAL NOT NULL DEFAULT 0,
  closing_amount REAL,
  expected_amount REAL,
  opened_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  closed_at TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','closed'))
);

CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount>0),
  currency_code TEXT NOT NULL,
  paid_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  payment_method TEXT,
  created_by TEXT REFERENCES app_users(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  business_id TEXT REFERENCES businesses(id),
  actor_user_id TEXT REFERENCES app_users(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  before_data TEXT,
  after_data TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS business_memberships_business_user_uq ON business_memberships(business_id,user_id);
CREATE UNIQUE INDEX IF NOT EXISTS organization_memberships_org_user_uq ON organization_memberships(organization_id,user_id);
CREATE UNIQUE INDEX IF NOT EXISTS warehouses_business_name_uq ON warehouses(business_id,name);
CREATE UNIQUE INDEX IF NOT EXISTS products_business_sku_uq ON products(business_id,sku) WHERE sku IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS products_business_barcode_uq ON products(business_id,barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS businesses_org_idx ON businesses(organization_id);
CREATE INDEX IF NOT EXISTS business_memberships_user_idx ON business_memberships(user_id,status);
CREATE INDEX IF NOT EXISTS products_business_name_idx ON products(business_id,name);
CREATE INDEX IF NOT EXISTS audit_logs_business_time_idx ON audit_logs(business_id,created_at DESC);
CREATE INDEX IF NOT EXISTS purchases_business_time_idx ON purchases(business_id,created_at DESC);
CREATE INDEX IF NOT EXISTS sales_business_sold_idx ON sales(business_id,sold_at DESC);
CREATE INDEX IF NOT EXISTS stock_movements_business_time_desc_idx ON stock_movements(business_id,occurred_at DESC);
CREATE INDEX IF NOT EXISTS stock_movements_product_time_idx ON stock_movements(product_id,occurred_at DESC);
CREATE INDEX IF NOT EXISTS sync_operations_business_status_idx ON sync_operations(business_id,status,created_at);
