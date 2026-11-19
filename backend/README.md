# GeStock API — Cloudflare Workers

The production API is TypeScript + Hono on Cloudflare Workers. Application data and identity are stored in Cloudflare D1 (`gestock-db`). No external authentication or database provider is used by the runtime.

## Deploy and verify
1. Set GitHub Actions secret `CLOUDFLARE_API_TOKEN` with permissions to deploy Workers and apply D1 migrations.
2. Push to `main`. Quality checks run Flutter analysis/tests, backend typecheck/tests, then apply versioned D1 migrations and deploy the API.
3. The workflow verifies `/health`, `/health/d1`, and registration/login/session/password-change/logout flows against the deployed API.

## D1
Migrations 0001–0005 are applied to the production D1 database. The auth migrations are additive and do not delete existing domain records. At the latest inspection, the application user/business/product/sale tables were empty. Do not drop the D1 database or auth tables for rollback.

## API capabilities
- Businesses: create/list, membership-scoped.
- Products: create/list and offline upsert synchronization.
- Stock: atomic movements, current levels and movement history; negative stock blocked by D1 triggers.
- Sales: atomic sale, sale lines, payment record and stock deduction; sync is idempotent.
- Sync: device registration and batches for business, product, stock movement and sale.
- Platform admin: read-only overview, businesses, sales, inventory/low-stock, sync operations and user directory. User/role CRUD and invitations are not implemented.

Mobile Money/card/bank payment records remain pending until an external provider verifies payment. No payment provider is connected.

## Admin web access
The Cloudflare Workers admin host is protected by Cloudflare Access with an allow policy for `editadigoun@gmail.com`. Admin API calls forward the Access JWT server-side; the API validates issuer, audience and allowlisted email. The mobile client uses D1 sessions and secure device storage.

## Authentication
- Register/login with salted PBKDF2-SHA-256 (100,000 iterations).
- 256-bit random bearer tokens; SHA-256 digests stored in D1; 30-day expiry and revocation.
- Login/register rate limiting.
- Password change revokes other sessions.
- Email verification and recovery email are not implemented. A support/admin recovery flow remains a release blocker.

Never commit secrets. The D1 binding is named `DB`.
