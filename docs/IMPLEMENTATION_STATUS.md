# GeStock implementation status

## Verified 19 November 2026 (20:10 CET)

- Repository default branch is `main`. Latest source commit checked: `2873cb91bd9b89b6e2815ce42b630dd4ede28d08` (test-only fix to await the duplicate-barcode assertion). Its Vercel production deployment is **READY**: [deployment](https://vercel.com/ccds22431-9924/gestock-admin/5FWuGrXSMjorWsQ5xsJgAxdBCeJb).
- Latest fully inspected GitHub Actions quality run, `44571921649`, passed Flutter analyze/tests, backend typecheck/tests, D1 migrations, API deployment and health checks. It ran for `c06add3190e4f35561bcd57ecc3998eaba50df09`, immediately before the test-only HEAD commit. The available GitHub connector cannot enumerate push-triggered runs/check-runs for `2873cb9`; therefore CI for the exact HEAD is not confirmed here.
- Android release build run `44571921560` succeeded for `c06add3`. GitHub artifact `14553808781` (`GeStock-Android-APK`) was downloaded and verified: ZIP SHA-256 `5c9c1081fb4d0f4493c8332671dd77b230e3fd1c283a1b90422116446f706817`. The ZIP contains a 54,584,743-byte APK and its checksum file. APK SHA-256 recomputed from the mounted file and checked against the sidecar: `187c5e47ffe7266d3b17cf6fcd33e51972a396d4279129b88b524da82053cd76`. APK is Debug-signed; no production signing key or Play Store AAB is configured.
- API Worker `gestock-api` is active in Cloudflare: latest deployment `7e34d1d7-62d7-4e0c-aacf-e36d1631959f`, 100% traffic, deployed 18:00:46 UTC. API health/D1 checks passed in run `44571921649`.
- Admin Worker `gestock-admin` is active: latest deployment `27084fd2-9684-4e49-a385-e1eafdbfd7d0`, 100% traffic, deployed 16:57:37 UTC. Canonical console: https://gestock-admin.ccds22431.workers.dev.
- Cloudflare Access is enabled in account `ed1783922fcd87086ef7757e242fc0f2`. App `GeStock Admin Console` protects the canonical admin Worker; 24-hour session and Allow policy `Allow GeStock Administrator` include only `editadigoun@gmail.com`. CI run [44561527098](https://github.com/editadigoun-cmd/GeStock/actions/runs/44561527098) verified the unauthenticated edge redirect before enabling the Worker trust flag. Neon Auth remains the second authentication layer; native mobile still uses Neon Auth. Vercel is not behind this Access app, so use the Cloudflare Worker URL as canonical.
- D1 database `gestock-db` was queried read-only. 26 SQLite tables are present including Cloudflare internal `_cf_KV` and migration ledger `d1_migrations`; the API health count excludes those and reports 24 application tables. Migrations `0001`–`0003` are recorded. All queried business data tables are empty (0 users, organizations, businesses, products, sales, stock, sync operations, etc.). No Neon or D1 business data was changed.

## Connected workflows

- Mobile: business setup and workspace switching; country/currency/timezone; offline product create/edit with SKU/barcode/prices/tax/threshold; opening stock and adjustments with movement history; POS sale with payment record and local stock deduction; durable outbox and sales history.
- Backend: business, product, stock and sales endpoints; idempotent sync, membership-scoped access, stock updates, sales and history. D1 triggers guard against negative stock.
- Admin read-only: overview, businesses, recent sales/payments, low-stock inventory, sync operations and searchable users with memberships/devices/activity. Endpoint `GET /v1/admin/users`. Empty states are real database results, not mock/demo data. User/role writes, invites and permission management remain unimplemented.
- Local SQLite schema version 4. Tests cover business/catalogue/initial stock/adjustments/POS/outbox and pending product-edit coalescing. Flutter analyze/tests passed in run `44571921649` for commit `c06add3`.

## Remaining work / release gates

- Admin: user/role CRUD, invitations, billing/subscriptions, ads, support, audit UI and global settings require backend capabilities.
- Mobile: provider-confirmed electronic payments, cash sessions, refunds/returns, purchasing/receiving, customer credit, receipts/printing, warehouse transfers and a full conflict-resolution UI remain incomplete.
- Production Android signing, signed AAB/Play Store, iOS and real-device testing are not verified.
- Neon-to-D1 migration and end-to-end real-device sync are not verified. Preserve Neon and all existing data until a tested migration and rollback plan exist.
