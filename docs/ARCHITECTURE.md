# GeStock — Technical architecture

## Product constraints

GeStock supports multiple businesses per user. Each workspace is isolated by business, with its own currency, country, timezone, locations, warehouses, catalogue, staff and permissions.

Mobile must work offline. Local writes commit to SQLite first and a durable outbox; sync is asynchronous and idempotent. Electronic payments remain pending until provider confirmation.

## Implemented stack

- Mobile: Flutter/Dart, Material 3, Riverpod, go_router.
- Local persistence: SQLite/sqflite, schema version 4.
- API: TypeScript + Hono on Cloudflare Workers.
- Domain data: Cloudflare D1, Drizzle, migrations 0001–0003.
- Identity: Neon Managed Auth; business-membership checks scope domain APIs.
- Admin: Next.js/Vinext on Cloudflare Workers, read-only real-data pages.
- Cloudflare Access protects the canonical admin Worker; Neon Auth is retained as the second layer. Native mobile uses Neon Auth.
- AI, push, object storage and monetization are deferred.

Neon remains the identity provider and existing Neon data is preserved. Neon-to-D1 migration is not verified.

## Domain model

1. Identity/profile, organizations, businesses and memberships.
2. Locations, warehouses, product categories, catalogue and barcodes.
3. Stock levels and immutable movements.
4. Sales, lines, payments, returns and receipts.
5. Purchasing, suppliers and receiving.
6. Customers, balances and credit.
7. Cash registers, sessions and expenses.
8. Reporting, notifications and audit.
9. Devices, sync operations and conflicts.
10. Entitlements and monetization.

## Data isolation and integrity

Every business-owned row includes its business scope. API handlers derive the actor from verified identity, validate membership and scope queries. Stock is recorded as movements and stock-level updates are atomic; D1 guards against negative stock.

## Offline synchronization

- SQLite is the local source of truth.
- Mutations use operation/device IDs and a durable outbox.
- Server-side processed operation IDs prevent duplicate application.
- Business, product, stock movement and sale sync paths are implemented.
- Local tests cover business setup, catalogue create/edit, initial stock, adjustments, POS and queued operations.
- Remote synchronization on a physical device is not yet verified. Conflicts are retained; full conflict-resolution UI and automatic resolution remain incomplete.
- Provider-confirmed electronic payment is not implemented; payments must remain pending until a provider verifies them.

## Admin read-only API

- `GET /v1/admin/overview`
- `GET /v1/admin/businesses`
- `GET /v1/admin/sales`
- `GET /v1/admin/inventory` (low stock)
- `GET /v1/admin/sync`
- `GET /v1/admin/users` (directory with membership/device/activity data)

The admin console displays actual backend data and empty states, not demo values. User/role mutation, invitations, billing, ads, support, audit UI and global settings are not implemented.

## Security

Cloudflare Access is enabled in account `ed1783922fcd87086ef7757e242fc0f2`. Application `GeStock Admin Console` protects `gestock-admin.ccds22431.workers.dev` and allows only `editadigoun@gmail.com`, with a 24-hour session. The edge redirect was verified in CI before enabling `CLOUDFLARE_ACCESS_ENABLED`; Access identity headers are only trusted when this flag is enabled after the edge check. Neon Auth remains required for API/admin identity.

The alternate Vercel deployment is not covered by this Access application. Use the Cloudflare Worker URL as the canonical admin console.

## Current infrastructure

- API Worker: `gestock-api`.
- Admin Worker: `gestock-admin`.
- D1: `gestock-db`; 24 health-counted application tables, plus `d1_migrations` and internal `_cf_KV`; migrations 0001–0003.
- Android: GitHub Actions release APK and `android-latest` release checksum; APK currently Debug-signed.
- See `docs/IMPLEMENTATION_STATUS.md` for the latest verification record and build links.

## Release gates

1. Run a physical-device smoke test for business setup, product, stock adjustment, POS and online/offline sync.
2. Complete conflict-resolution UX and provider-verified payment; cash, purchasing, returns, credit, receipts and warehouse transfer.
3. Production Android signing key, signed AAB, iOS build and store release.
4. Admin write operations/roles, audit, billing, support and settings.
5. Plan and verify a Neon-to-D1 data migration with rollback; do not migrate or delete existing data before validation.
