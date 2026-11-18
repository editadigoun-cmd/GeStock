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
- Product screen is now the main inventory screen; dashboard demo KPIs remain explicitly identified as demonstration data.
- Neon Managed Auth is enabled on the GeStock main branch; email/password sign-up is enabled.
- Hono API has JWT middleware, business creation/listing, membership-scoped product endpoints, and a transactional stock movement endpoint.
- New business API creation provisions an initial warehouse.
- Sync device registration endpoint creates/reuses a device scoped to the authenticated app user.
- Sync batch endpoint processes business, product and stock-movement outbox operations in order.
- Business sync preserves the local business and default-warehouse UUIDs across devices.
- Sync operation keys are deduplicated by the existing unique business-and-operation-key constraint.
- Stock movement sync is append-only and idempotent; stock level increments are atomic and negative resulting stock is rejected.
- Mobile SyncService keeps a durable SQLite outbox, registers the device, sends batches with the Neon Auth bearer token, and removes only operations confirmed as applied.
- Mobile dashboard attempts pending sync on entry and when connectivity returns; if API configuration is absent or the device is offline, local data remains available.
- Product creation queues its product record before its opening stock movement.
- Repaired escaped newline corruption in the mobile auth repository and backend business route.
- GitHub Actions workflow configured for Flutter analyze/test and backend typecheck.

## Not yet verified / not production-ready
- No Android/iOS build or Flutter analyze/test result has been obtained in this environment.
- Managed Auth REST cookie/token behavior still needs real-device verification. Production email delivery requires custom SMTP and production trusted origins.
- Sync code has been committed but has not yet been tested end-to-end against a deployed API and real Android/iOS devices. Conflict/rejected operations remain in the local outbox for inspection; automatic conflict resolution and a user-facing retry/recovery screen are still pending.
- The API has not been deployed; production database URL, Auth issuer/audience/JWKS settings and allowed app origins are not configured.
- Dashboard financial KPIs remain demonstration data.
- POS transactions, cash sessions, purchase workflows, returns, payments, receipts, expenses, reporting and staff permissions remain to be implemented.

## Next development gates
1. Run Flutter analyze/test and backend typecheck in CI; fix all compile errors.
2. Verify login/session restoration and offline-to-online sync on Android and iOS.
3. Add a user-facing sync status/retry screen and conflict resolution workflow.
4. Implement full stock ledger querying, warehouse switching and inventory count workflows.
5. Build transactional POS, payments, cash sessions, returns and receipts.
6. Replace demo dashboard KPIs with real local/cloud aggregates.
7. Produce signed Play Store/App Store builds after end-to-end verification.
