# GeStock implementation status

## Foundation delivered
- Flutter navigation shell and Emerald Intelligence design tokens.
- Sign-in and sign-up UI wired to Neon Managed Auth REST endpoints.
- Neon Managed Auth provisioned on the GeStock main branch (email/password enabled; shared development email delivery).
- Local SQLite database for business workspaces, products and a durable outbox.
- Local repositories for business and product creation.
- Product catalogue, inventory and sales module surfaces.
- Hono API scaffold with JWT verification, business creation/listing, membership-scoped product routes and sync intake.
- Drizzle schema mappings for core business, membership, product and sync tables.

## Important production gates
- Neon Auth is enabled, but production SMTP, trusted redirect origins and the JWT plugin/issuer/audience settings still need verification.
- Flutter login cookie persistence and JWT retrieval must be tested against real Android and iOS builds before relying on it.
- API deployment and secret configuration are not done. Do not publish the API until the issuer, audience, JWKS URL and database connection are set.
- Sync endpoint is an intake scaffold, not a complete synchronizer. Device registration, membership checks for each queued operation, domain processing, retries and conflict resolution still need implementation.
- Stock movement ledger, transactional POS, payments, returns, receipts and complete reporting are not implemented.
- Product records are currently saved locally; the mobile app is not yet connected to the API sync worker.
- Flutter analyze, backend typecheck and device builds have not run in this environment.

## Next gates
1. Verify Managed Auth REST cookie/token flow and configure production email delivery.
2. Add device registration and complete outbox synchronization with idempotent domain transactions.
3. Implement stock ledger and transaction-safe stock level updates.
4. Complete POS, cash sessions, returns and receipt generation.
5. Add full workspace switching, roles and permission management.
6. Run Flutter analysis/tests, API typecheck/tests, Android/iOS builds and offline end-to-end tests.
