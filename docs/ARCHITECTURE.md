# GeStock — Technical architecture

## Product constraints
GeStock serves multiple businesses per user account. Each business is an isolated workspace with its own currency, country, timezone, locations, warehouses, catalogue, staff, permissions and operational data.

The mobile application must remain useful without a network connection. Local writes are committed first to SQLite and a durable outbox. Synchronization is asynchronous, idempotent and conflict-aware. Electronic payment must not be marked confirmed until a provider verifies it.

## Implemented stack
- Mobile: Flutter/Dart, Material 3 with custom GeStock design system.
- Local persistence: SQLite via sqflite (not Drift yet); schema version 4.
- State: Riverpod; navigation: go_router.
- API: TypeScript + Hono on Cloudflare Workers.
- Domain database: Cloudflare D1 (SQLite), Drizzle ORM and migrations 0001–0003.
- Identity: Neon Managed Auth; domain authorization checks business membership.
- Web administration: Next.js/Vinext on Cloudflare Workers. Admin routes are read-only and Neon Auth protected; Cloudflare Access is not yet enabled.
- AI, push, object storage and monetization are deferred.

Neon remains the identity provider and its existing domain data is preserved. A Neon-to-D1 migration is not verified.

## Core domains
1. Identity and account profile.
2. Organizations, businesses and memberships.
3. Locations and warehouses.
4. Product catalogue, categories, variants and barcodes.
5. Inventory levels and immutable stock movements.
6. Sales, sale lines, payments, returns and receipts.
7. Purchasing, suppliers and receiving.
8. Customers, balances and credit.
9. Cash registers, cash sessions and expenses.
10. Reporting, notifications and audit history.
11. Devices, sync operations and conflict resolution.
12. Entitlements and monetization.

## Data isolation and integrity
Every business-owned record carries a business identifier. API handlers derive the actor from a verified session, validate active business membership and scope each query. Stock changes are represented as movements and applied atomically with stock-level updates. D1 triggers prevent negative stock.

## Offline synchronization
- SQLite is the mobile UI source of truth.
- Each mutation has a globally unique operation ID and device ID.
- The outbox is durable across restarts.
- The server records processed operation IDs to prevent duplicate application.
- Business, product, stock movement and sale sync are supported.
- Offline workflow tests exercise business setup, product create/edit, opening stock, adjustments, POS and queued operations. Remote sync on a real device is still unverified.
- Conflicts are retained for retry/inspection; automatic resolution and a full UI are not complete.
- Electronic payment remains pending until provider verification.

## Admin read-only endpoints
- \`/v1/admin/overview\`
- \`/v1/admin/businesses\`
- \`/v1/admin/sales\`
- \`/v1/admin/inventory\` (low stock)
- \`/v1/admin/sync\` (summary and recent operations)

User/role CRUD, billing, ads, support, audit UI and global settings are not implemented. Access identity headers are only accepted when the explicit edge-protection flag is enabled; it remains off until Cloudflare Access is enabled.

## Current deployment
- API: \`gestock-api\` Cloudflare Worker.
- Admin: \`gestock-admin\` Cloudflare Worker.
- D1 database: \`gestock-db\`, migrations 0001–0003 (24 application tables).
- Android: GitHub Actions release-mode APK and \`android-latest\` release with SHA-256.

## Next gates
1. Enable Cloudflare Access manually and configure the admin allow policy for editadigoun@gmail.com.
2. Verify login/offline-to-online sync on a real Android device.
3. Implement conflict resolution, user roles, payment provider, cash sessions, returns, purchasing, customer credit and receipts.
4. Signed Play Store/App Store build and data migration verification.
