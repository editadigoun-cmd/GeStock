# GeStock — Technical architecture

## Product constraints
GeStock supports multiple businesses per user, isolated by business membership. Mobile remains offline-first using SQLite and a durable outbox. Sync is idempotent. Provider-confirmed electronic payments are not implemented.

## Cloudflare-only infrastructure
- Flutter/Dart mobile; local SQLite.
- API: TypeScript/Hono on Cloudflare Workers.
- Business and authentication records: Cloudflare D1, Drizzle and migrations.
- Web administration: Cloudflare Workers/Vinext.
- Admin protection: Cloudflare Access, allowlisted administrator.
- Mobile/API authentication: D1 user records, salted PBKDF2-SHA-256 password hashes, random opaque session tokens, SHA-256 token hashes, 30-day expiry and revocation.
- Admin API: signed Cloudflare Access JWT forwarded server-side and validated against issuer, audience and administrator email.
- Source and automation: GitHub main branch only.

Auth migration is additive (migrations 0004/0005). Rollback means redeploying a prior Worker version without reverting/dropping D1 tables. Keep the former proxy only until live tests and mobile release adoption pass, then decommission it; it is not called by current source.

## Domain model
Users, organizations, businesses/memberships, locations/warehouses, product catalogue, stock movements/levels, sales/lines/payments, purchasing/suppliers, customers, cash registers/sessions, expenses, audit, devices and sync operations.

## Integrity and isolation
Server derives user identity from verified sessions; admin identity is verified Access JWT. Memberships scope business data. Stock movement writes are atomic and negative-stock triggers remain.

## Offline synchronization
Local writes commit to SQLite and outbox before network. Server operation IDs prevent duplicate application. Business, product, stock movement and sale synchronization exists. Physical-device remote sync and full conflict UI remain unverified/incomplete.

## Admin read-only endpoints
GET /v1/admin/overview, businesses, sales, inventory, sync and users. User/role writes, invitations, billing, ads, support, audit UI and full settings remain incomplete.

## Auth limitations
No email verification or email-delivered password recovery. A user who forgets their mobile password must contact support; admin account recovery is managed by Cloudflare Access/identity provider. The new auth flow must pass CI and live registration/login/session/logout/admin JWT tests before legacy auth resources are removed.
