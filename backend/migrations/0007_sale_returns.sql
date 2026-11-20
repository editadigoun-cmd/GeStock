CREATE TABLE IF NOT EXISTS sale_returns (
 id TEXT PRIMARY KEY,business_id TEXT NOT NULL,sale_id TEXT NOT NULL,return_number TEXT NOT NULL,
 reason TEXT NOT NULL,refund_method TEXT NOT NULL,refund_amount REAL NOT NULL,status TEXT NOT NULL DEFAULT 'completed',
 returned_at TEXT NOT NULL,created_by TEXT,created_at TEXT DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(business_id,return_number)
);
CREATE INDEX IF NOT EXISTS sale_returns_sale_idx ON sale_returns(sale_id);
CREATE TABLE IF NOT EXISTS sale_return_items (
 id TEXT PRIMARY KEY,return_id TEXT NOT NULL,sale_item_id TEXT NOT NULL,product_id TEXT,
 product_name_snapshot TEXT NOT NULL,quantity REAL NOT NULL,unit_price REAL NOT NULL,refund_amount REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS sale_return_items_return_idx ON sale_return_items(return_id);
