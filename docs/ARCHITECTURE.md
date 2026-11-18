# GeStock — Technical architecture

## Product constraints
GeStock serves multiple businesses per user account. Each business is an isolated workspace with its own currency, country, timezone, locations, warehouses, catalogue, staff, permissions and operational data.

The mobile application must remain useful without a network connection. Local writes are committed first to a local database and an outbox. Synchronization is asynchronous, idempotent and conflict-aware. A payment provider response must be verified online before a mobile-money/card payment is marked confirmed.

## Proposed stack
- Mobile: Flutter / Dart, Material 3 with a custom GeStock design system.
- Local persistence: SQLite via Drift (offline-first source of truth).
- State: Riverpod.
- Navigation: go_router.
- API: TypeScript + Hono, with OpenAPI contracts.
- Cloud database: Neon PostgreSQL; Drizzle ORM and versioned migrations.
- Authentication: Neon Managed Auth where its current feature set fits; business membership and fine-grained authorization remain in the GeStock domain.
- Files: private object storage with signed upload/download URLs.
- Push: Firebase Cloud Messaging.
- Web administration: Next.js, introduced after the core mobile workflows.
- AI: deferred until the core product is stable.

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
12. Entitlements and monetization (introduced only after core workflows).

## Data isolation and integrity
Every business-owned record carries a business identifier. API handlers must derive the acting user from a verified session, validate active business membership and permissions, and scope every query to that business. Never trust a client-supplied business ID without checking membership.

Stock changes are represented as movements and must be applied transactionally with stock-level updates. Completed financial records are corrected through reversals/refunds rather than silently erased. Use decimal numeric types for money and quantities.

## Offline synchronization
- Local database is the UI source of truth.
- Every local mutation receives a globally unique operation ID and device ID.
- The outbox is durable across app restarts.
- The server records processed operation IDs to prevent duplicate application.
- Server responses include canonical entity versions and conflict details.
- Conflicts are explicit and recoverable; never silently use last-write-wins for stock or money.
- Pending electronic payments remain pending until provider verification.

## Delivery sequence
1. Mobile design system, navigation and dashboard foundation.
2. Authentication, account setup and multi-business workspace.
3. Catalogue and inventory, including offline writes and sync.
4. Sales/POS, receipts, cash sessions and returns.
5. Purchasing, suppliers, customers, expenses and reports.
6. Staff permissions, multi-location workflows and administration.
7. Hardening, accessibility, performance, backups, security and store release.
8. AI features only after usage data and core workflows justify them.

## Current database
Neon project: `blue-brook-96295181`, database: `gestock`, primary branch: `main`. The first 24-table foundation migration has been applied and verified. It is a starting schema, not a claim that all business rules or authorization policies are complete.
