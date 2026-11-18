# GeStock implementation status

## Completed in this pass
- Flutter sign-in/sign-up screens connected to the Neon Managed Auth REST endpoints.
- Auth cookie stored with platform secure storage; startup attempts to restore a session using the Managed Auth token endpoint.
- Local SQLite v2 with additive migration for warehouses and stock movement history.
- Business creation creates a local workspace and its default warehouse in one local transaction.
- Multi-business list and active-workspace switcher are accessible from bottom navigation and dashboard.
- Product catalogue uses the active workspace and supports local product creation.
- Product initial stock is recorded as an opening movement.
- Product stock entry/exit operations update local quantities and append immutable local movement records plus outbox events.
- Product screen is now the main inventory screen; dashboard no longer falsely reports cloud sync as complete.
- Neon Managed Auth is enabled on the GeStock main branch; email/password sign-up is enabled.
- Hono API has JWT middleware, business creation/listing, membership-scoped product endpoints, and a transactional stock movement endpoint.
- New business API creation provisions an initial warehouse.
- GitHub Actions workflow configured for Flutter analyze/test and backend typecheck.

## Not yet verified / not production-ready
- No Android/iOS build or Flutter analyze/test result has been obtained in this environment.
- Managed Auth REST cookie/token behavior still needs real-device verification. Production email delivery requires custom SMTP and production trusted origins.
- Business creation and product/stock writes currently persist locally first. The mobile outbox is durable, but a complete authenticated sync worker and server-side operation processor are not yet enabled.
- The sync API intentionally returns 501 until device registration, idempotent domain processing and conflict resolution are completed.
- The API has not been deployed; production database URL, Auth issuer/audience/JWKS settings and allowed app origins are not configured.
- Dashboard financial KPIs remain clearly marked as demonstration data.
- POS transactions, cash sessions, purchase workflows, returns, payments, receipts, expenses, reporting and staff permissions remain to be implemented.

## Next development gates
1. Verify login/session restoration on Android and iOS.
2. Implement device registration and idempotent business/product/stock outbox synchronization.
3. Implement full stock ledger querying, warehouse switching and inventory count workflows.
4. Build transactional POS, payments, cash sessions, returns and receipts.
5. Replace demo dashboard KPIs with real local/cloud aggregates.
6. Add end-to-end offline/reconnect tests and produce signed Play Store/App Store builds.
