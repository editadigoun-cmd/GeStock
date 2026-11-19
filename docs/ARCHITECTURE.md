# GeStock — Technical architecture

## Product constraints
GeStock supports multiple businesses per user, isolated by business membership. Mobile remains offline-first using SQLite and a durable outbox. Sync is idempotent. Provider-confirmed electronic payments are not implemented.

## Cloudflare-only infrastructure
- Flutter/Dart mobile; local SQLite.
- API: TypeScript/Hono on Cloudflare Workers.
- Business and authentication records: Cloudflare D1, Drizzle and versioned migrations.
- Web administration: Cloudflare Workers/Vinext.
- Admin protection: Cloudflare Access, administrator allowlist.
- Mobile/API authentication: D1 users, PBKDF2-SHA-256 hashes (100,000 iterations, unique salt), random opaque session tokens, SHA-256 token hashes, 30-day expiry and revocation.
- Admin API: Cloudflare Access JWT validated against issuer, audience and administrator email.
- Source and automation: GitHub main branch only.

## Data and rollback
Migrations 0004 and 0005 are additive: password/session fields and rate-limit storage. Existing application tables are not dropped or rewritten. Rollback is to a known-good Cloudflare Worker version while retaining the D1 schema/data; do not roll back by dropping auth tables. The former auth proxy and its obsolete Worker secret have been removed after CI validated the new auth flow.

The previous external identity source was not audited/exported in this environment. D1 had zero user/business/product/sale records at the latest inspection. Existing external identity data, if any, remains untouched and disconnected; review/export/retention must be decided before deleting that data. See [migration and rollback procedure](AUTH_MIGRATION_ROLLBACK.md).

## Domain model
Users, organizations, businesses/memberships, locations/warehouses, product catalogue, stock movements/levels, sales/lines/payments, purchasing/suppliers, customers, cash registers/sessions, expenses, audit, devices and sync operations.

## Integrity and isolation
Server derives mobile identity from validated sessions; admin identity is a verified Access JWT. Memberships scope business data. Stock movement writes are atomic and negative-stock triggers remain.

## Offline synchronization
Local writes commit to SQLite and a durable outbox before network. Server operation IDs prevent duplicate application. Business, product, stock movement and sale synchronization exists. Physical-device remote sync and full conflict UI remain unverified/incomplete.

## Admin read-only endpoints
GET /v1/admin/overview, businesses, sales, inventory, sync and users. User/role writes, invitations, audit UI, support, monetization and full settings remain incomplete.

## Authentication limitations
No email verification or email-delivered password recovery. Users who lose access need a controlled support/admin recovery process, which is not implemented. Admin recovery is handled by Cloudflare Access/identity provider.
