# GeStock implementation status

## Verified 19 November 2026

- Source verification: commit `587f14e168317f33c66d156dd62d2de38564f430`. GitHub Actions quality workflow passed: backend TypeScript typecheck/tests, Flutter analyze/tests, D1 migration check, API deployment, API health and D1 health.
- API Worker `gestock-api` deployed to `https://gestock-api.ccds22431.workers.dev`; `/health` and `/health/d1` passed in CI. Cloudflare deployment metadata shows the latest API deployment at 13:11 UTC on 19 November.
- Admin Worker `gestock-admin` deployed from commit `11ddccb46cadc52d806ab57313a4212b1a65b873`; build and login-page smoke test passed. Cloudflare deployment metadata shows the latest admin deployment at 13:03 UTC on 19 November.
- Android release APK built successfully from commit `587f14e168317f33c66d156dd62d2de38564f430` (Actions run 44529736367). Artifact ZIP SHA-256: `6e088e5eea572de82f3c19776adeedaf2a4e47b9a7fdc011d006624a8a5be627`.
- APK size: 54,584,743 bytes. The APK's SHA-256 was independently recomputed from the downloaded workflow artifact and matched the accompanying checksum: `97ba0405fe28253f9dbf264d32d5942bd2ea0974b2dd0c78b765f9a81d9591f6`. The APK v2 signing block and signature were cryptographically verified. The signer certificate is the Android Debug certificate; this is suitable for test/sideload use, not a production Play Store upload key. A production signing keystore and signed AAB remain unconfigured.
- Cloudflare D1 migrations `0001`–`0003` are applied. Read-only queries confirm 24 application tables, and users, organizations, businesses, products, sales, stock movements, sync operations and other operational tables contain zero rows. Neon and existing data were not modified.

## Connected workflows

- Mobile business setup and active-business switching.
- Offline catalogue creation and editing (long-press a product), SKU/barcode, purchase/sale price, tax and minimum-stock threshold.
- Initial stock and stock adjustments, with a durable offline outbox and movement history.
- Offline POS sale, line/payment records, local stock deduction and sale sync queue.
- Backend sale creation, sale history/detail, stock movements, atomic stock updates and idempotent sync.
- Admin web console is real-data read-only: overview, businesses, recent sales/payments, low-stock products, sync operations/statuses, and a searchable user directory (active business/organization memberships, devices, and last sync activity). Empty D1 results are displayed as empty, not demo data. The directory endpoint is `GET /v1/admin/users`; user/role mutation, invitations, and detailed permissions remain missing.
- SQLite schema is version 4. The migration adds `default_warehouse_id` to existing local business databases. Offline workflow tests cover business setup, catalogue, opening stock, adjustments, POS and outbox, plus pending product-edit coalescing.

## Security verification

- Cloudflare Access organization **GeStock Admin** is enabled in account `ed1783922fcd87086ef7757e242fc0f2` (created through the supported API). Login domain: `dark-bush-1837.cloudflareaccess.com`.
- Access application `GeStock Admin Console` protects `gestock-admin.ccds22431.workers.dev` (app ID `3b0bbfec-3667-45c7-8691-a117d47fc269`) with a 24-hour session. Policy `Allow GeStock Administrator` (ID `bb1633ad-7f68-43da-876b-4a5e92ede12a`) allows only `editadigoun@gmail.com`.
- The Cloudflare deployment workflow verified the unauthenticated edge redirect to Cloudflare Access in run [44561527098](https://github.com/editadigoun-cmd/GeStock/actions/runs/44561527098) before setting the Worker secret `CLOUDFLARE_ACCESS_ENABLED=true`. The admin Worker therefore trusts Access identity headers only after edge enforcement passed. Neon Auth remains required for the admin session/API token as a second layer. Native mobile remains on Neon Auth.
- Vercel deployments are not covered by this Access application; the alternate Vercel admin still relies on Neon Auth and administrator checks. Use the Cloudflare Worker URL as the canonical Access-protected console.

## Remaining blockers
- Admin user/role CRUD, billing/subscriptions, ads, support, audit UI and global settings need backend capabilities.
- Mobile provider-confirmed payments, cash sessions, refunds/returns, purchasing, customers/credit, receipt printing, multi-warehouse transfers and conflict-resolution UI remain incomplete.
- Production Android signing, a signed Play Store AAB, iOS, store release and real-device testing are not verified.
- Neon-to-D1 migration and real-device end-to-end online sync are not verified. Preserve Neon and existing data.
