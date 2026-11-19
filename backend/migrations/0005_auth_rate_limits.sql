CREATE TABLE IF NOT EXISTS auth_rate_limits (key_hash TEXT PRIMARY KEY, window_started_at TEXT NOT NULL, attempts INTEGER NOT NULL, last_attempt_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS auth_rate_limits_last_attempt_idx ON auth_rate_limits(last_attempt_at);
