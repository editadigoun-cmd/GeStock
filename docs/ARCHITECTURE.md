# GeStock — Technical architecture

## Product constraints
GeStock supports multiple businesses per user. Each workspace is isolated by business, with its own currency, country, timezone, locations, warehouses, catalogue, staff and permissions.

Mobile must work offline. Local writes commit to SQLite first and a durable outbox; sync is asynchronous and idempotent. Electronic payments remain pending until provider confirmation.

## Mandatory Cloudflare architecture
- Mobile: Flutter/Dart.
- Local persistence: SQLite/sqflite.
- API: TypeScript + Hono on Cloudflare Workers.
- Domain data: Cloudflare D1, Drizzle, migrations 0001–0003.
- Web admin: deployed on Cloudflare Workers.
- Admin security: Cloudflare Access, allow only the configured administrator.
- Identity target: Cloudflare-native authentication with D1-backed user records and secure token/session handling.
- Git: GitHub main branch only; production deployment is Cloudflare-only.

Any external hosting, identity, or domain-data provider is outside the approved architecture. The current identity implementation is legacy and must be replaced by the Cloudflare-native solution before removing it; preserve existing account records and implement a tested migration/rollback. Do not leave authentication or API authorization unavailable during transition.

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
Cloudflare Access protects the canonical admin Worker and restricts access to the configured administrator. Access identity headers are only trusted after verifying edge enforcement. API access must validate signed tokens issued by the approved Cloudflare-native authentication system and enforce business membership.

## Current infrastructure
- API Worker: `gestock-api`.
- Admin Worker: `gestock-admin`.
- D1: `gestock-db`; migrations 0001–0003.
- Android: GitHub Actions release APK and checksum; test signing currently used.

## Release gates
1. Replace the legacy external authentication and proxy with Cloudflare-native identity, sessions, token issuance/verification, account recovery and secure password storage. Test migration and rollback before deleting old resources.
2. Run a physical-device smoke test for business setup, product, stock adjustment, POS and online/offline sync.
3. Complete conflict-resolution UX and provider-verified payment; cash, purchasing, returns, credit, receipts and warehouse transfer.
4. Production Android signing key, signed AAB, iOS build and store release.
5. Admin write operations/roles, audit, support and settings.
