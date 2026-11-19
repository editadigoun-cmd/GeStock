# GeStock API — Cloudflare Workers

The production API is TypeScript + Hono on Cloudflare Workers. Domain data is stored in Cloudflare D1 (gestock-db); user identity and login remain on Neon Managed Auth. D1 is not a verified migration of the existing Neon database.

## Deploy and verify
1. Set the GitHub Actions secret CLOUDFLARE_API_TOKEN with permissions to deploy Workers and apply D1 migrations.
2. Push to main. Quality checks run Flutter analyze/tests, backend typecheck/tests, then apply versioned D1 migrations and deploy the API.
3. The workflow verifies /health and /health/d1.

The current D1 schema contains the 25 application tables from migrations 0001–0003. It was verified on 19 November 2026; the business, user, catalogue, sales, stock and sync tables were empty at that check. Existing Neon data was not modified or deleted.

## API capabilities
- Businesses: create/list, membership-scoped.
- Products: create/list and offline upsert synchronization.
- Stock: atomic movements, current levels and movement history; negative stock blocked by D1 triggers.
- Sales: atomic sale, sale lines, payment record and stock deduction; sync is idempotent.
- Sync: device registration and batches for business, product, stock movement and sale.
- Platform admin: read-only overview and business list restricted to the verified administrator email.

Mobile Money/card/bank payment records remain pending until an external provider is integrated and verifies payment. No payment provider is currently connected.

## Authentication
The API validates Neon Managed Auth JWTs using the configured issuer and JWKS. The admin API also requires a verified email claim matching ADMIN_EMAIL. Native mobile continues to use Neon Auth and secure device storage.

Never put Neon credentials or Cloudflare tokens in Git. The D1 binding is named DB.
