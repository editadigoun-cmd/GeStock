CREATE TABLE IF NOT EXISTS business_invitations (
 id TEXT PRIMARY KEY,
 business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
 email TEXT NOT NULL,
 role TEXT NOT NULL CHECK(role IN ('manager','cashier','staff')),
 token_hash TEXT NOT NULL UNIQUE,
 inviter_user_id TEXT REFERENCES app_users(id),
 created_at TEXT NOT NULL,
 expires_at TEXT NOT NULL,
 accepted_at TEXT,
 revoked_at TEXT
);
CREATE INDEX IF NOT EXISTS business_invitations_business_idx ON business_invitations(business_id,email);
CREATE INDEX IF NOT EXISTS business_invitations_expiry_idx ON business_invitations(expires_at);
