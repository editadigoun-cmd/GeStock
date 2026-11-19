# GeStock implementation status

## Verified 19 November 2026

- Latest mobile/backend source verification: commit \`587f14e168317f33c66d156dd62d2de38564f430\`. GitHub Actions quality workflow passed: backend TypeScript typecheck/tests, Flutter analyze/tests, D1 migration check, API deployment, API health and D1 health.
- API Worker \`gestock-api\` deployed to \`https://gestock-api.ccds22431.workers.dev\`; \`/health\` and \`/health/d1\` passed. D1 health reports 24 application tables.
- Admin Worker \`gestock-admin\` deployed from commit \`11ddccb46cadc52d806ab57313a4212b1a65b873\`; build and login-page smoke test passed.
- Android release APK workflow for commit \`587f14e168317f33c66d156dd62d2de38564f430\` is still running at this update; Flutter tests have passed. The final APK and checksum are not yet verified.
- Cloudflare D1 migrations \`0001\`–\`0003\` are applied. No migration was needed in this release. Read-only counts at verification: users, businesses, products, sales, stock movements and sync operations are all zero. Neon and existing data were not modified.

## Connected workflows

- Mobile business setup and active-business switching.
- Offline catalogue creation and editing (long-press a product), SKU/barcode, purchase/sale price, tax and minimum-stock threshold.
- Initial stock and stock adjustments, with a durable offline outbox and movement history.
- Offline POS sale, line/payment records, local stock deduction and sale sync queue.
- Backend sale creation, sale history/detail, stock movements, atomic stock updates and idempotent sync.
- Admin web console is real-data read-only: overview, businesses, recent sales/payments, low-stock products and sync operations/statuses. Empty D1 results are displayed as empty, not demo data.
- SQLite schema is version 4. The migration adds \`default_warehouse_id\` to existing local business databases. New offline workflow tests cover business setup, catalogue, opening stock, adjustments, POS and outbox, plus pending product-edit coalescing.

## Remaining manual blocker

- Cloudflare Access is not enabled on account \`ed1783922fcd87086ef7757e242fc0f2\`. The API returns \`access.api.error.not_enabled\` and instructs the dashboard Enable Access action. Enable Access in Workers & Pages for \`gestock-admin\`, then the allow policy for \`editadigoun@gmail.com\` can be created. Access identity headers are not trusted while the edge policy is disabled. Web admin still requires Neon Auth in addition to Access; this is intentionally not replaced without verified authorization.
- Admin user/role CRUD, billing/subscriptions, ads, support, audit UI and global settings need backend capabilities.
- Mobile provider-confirmed payments, cash sessions, refunds/returns, purchasing, customers/credit, receipt printing, multi-warehouse transfers and conflict-resolution UI remain incomplete.
- Android release APK is not a signed Play Store AAB; iOS and store release have not been verified.
- Neon-to-D1 migration and real-device end-to-end online sync are not verified. Preserve Neon and existing data.
