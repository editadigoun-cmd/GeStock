# GeStock implementation status

## Current baseline
- Repository default branch: `main`. Latest inspected source baseline: `b40988d40b64a0b4e27cec7fcd2347feb958c3df` before the Cloudflare-only architecture documentation commits.
- Cloudflare API Worker `gestock-api`, admin Worker `gestock-admin`, and D1 `gestock-db` are the intended production resources. Admin canonical URL: https://gestock-admin.ccds22431.workers.dev.
- Prior CI checks reported Flutter analysis/tests, backend typecheck/tests, migrations, API deployment and health passing; this must be rerun after current commits.
- Android pipeline publishes a test APK and checksum. Production Play Store signing and AAB are not configured.
- D1 has migrations 0001–0003. Previous inspection found application tables empty; confirm again before any migration.
- Cloudflare Access is intended to protect the admin Worker and restrict it to the administrator. Verify live edge enforcement on every deployment.

## Implemented workflows
- Mobile: business setup and workspace switching; country/currency/timezone; offline product create/edit with SKU/barcode/prices/tax/threshold; opening stock and adjustments with movement history; POS sale with payment record and local stock deduction; durable outbox and sales history.
- Backend: business, product, stock and sales endpoints; idempotent sync, membership-scoped access, stock updates, sales and history. D1 triggers guard against negative stock.
- Admin read-only: overview, businesses, recent sales/payments, low-stock inventory, sync operations and searchable users with memberships/devices/activity. Endpoint `GET /v1/admin/users`. User/role writes, invites and permission management remain unimplemented.

## Mandatory architecture change — release blocker
The approved target is Cloudflare-only: Workers for API and admin, D1 for data, Cloudflare Access for admin protection, and Cloudflare-native authentication for mobile/API identity. No alternate hosting, external identity provider, or external domain-data database is to be used.

The current code still contains a legacy external authentication integration and its proxy. It must be replaced—not merely hidden—with Cloudflare-native auth including password hashing, signup/sign-in, session/token issue and validation, secure token refresh/revocation, account recovery, admin authorization, and a verified account migration/rollback. Preserve existing user/account data until migration is verified. Do not delete the old auth resources or switch mobile/API runtime settings until replacement tests pass.

## Remaining work / release gates
1. Implement Cloudflare-native authentication in Worker + D1, including migration and rollback; migrate admin and Flutter clients; remove legacy proxy, config, workflows, secrets, and dependencies after verification.
2. Verify Cloudflare Access edge protection and admin identity restriction.
3. Rerun main CI: Flutter analyze/tests, backend typecheck/tests, D1 migrations and Cloudflare deploy/health checks.
4. Test remote sync on a physical device, including offline/online transitions and conflict recovery.
5. Complete mobile features: provider-confirmed electronic payments, cash sessions, refunds/returns, purchasing/receiving, customer credit, receipts/printing, warehouse transfers and conflict-resolution UI.
6. Complete admin user/role writes, invitations, audit, support and settings.
7. Production Android signing, signed AAB, iOS and store release.
