CREATE TABLE IF NOT EXISTS cash_registers (
 id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,location_id TEXT,is_active INTEGER NOT NULL DEFAULT 1,created_at TEXT DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(business_id,name)
);
CREATE TABLE IF NOT EXISTS cash_sessions (
 id TEXT PRIMARY KEY,business_id TEXT NOT NULL,register_id TEXT NOT NULL,opened_by TEXT,closed_by TEXT,
 opening_amount REAL NOT NULL DEFAULT 0,closing_amount REAL,expected_amount REAL,opened_at TEXT NOT NULL,closed_at TEXT,status TEXT NOT NULL DEFAULT 'open',
 created_at TEXT DEFAULT CURRENT_TIMESTAMP,updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS cash_sessions_business_opened_idx ON cash_sessions(business_id,opened_at);
CREATE UNIQUE INDEX IF NOT EXISTS cash_sessions_one_open_register_idx ON cash_sessions(register_id) WHERE status='open';
