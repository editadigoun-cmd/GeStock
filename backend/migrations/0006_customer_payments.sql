CREATE TABLE IF NOT EXISTS customer_payments (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount > 0),
  payment_method TEXT NOT NULL,
  note TEXT,
  paid_at TEXT NOT NULL,
  created_by TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS customer_payments_business_customer_time_idx
  ON customer_payments(business_id, customer_id, paid_at);
