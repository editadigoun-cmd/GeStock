CREATE TABLE IF NOT EXISTS auth_email_tokens (
 id TEXT PRIMARY KEY,
 user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 token_hash TEXT NOT NULL UNIQUE,
 token_type TEXT NOT NULL CHECK(token_type IN ('verify_email','reset_password')),
 expires_at TEXT NOT NULL,
 used_at TEXT,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS auth_email_tokens_user_type_idx ON auth_email_tokens(user_id,token_type,used_at);
CREATE INDEX IF NOT EXISTS auth_email_tokens_expiry_idx ON auth_email_tokens(expires_at);
