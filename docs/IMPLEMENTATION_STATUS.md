# GeStock implementation status

## Delivered in this pass
- Flutter navigation shell and Emerald Intelligence design tokens.
- Sign-in and sign-up screens wired to the Neon Managed Auth REST endpoints.
- Neon Managed Auth provisioned on the GeStock main branch; email/password is enabled.
- Local SQLite database for business workspaces, products and a durable outbox.
- Local repositories for business and product creation.
- Product catalogue, inventory and sales module surfaces.
- Hono API scaffold with JWT verification, business creation/listing and membership-scoped product routes.
- Drizzle schema mappings for app users, organizations, business memberships, products and sync operations.
- GitHub Actions workflow for Flutter analysis/tests and backend type checking.

## Important production gates
- Neon Auth is enabled, but production SMTP, trusted origins and JWT issuer/audience settings still need verification.
- Flutter login cookie persistence and JWT retrieval must be tested against real Android and iOS builds.
- API deployment and secret configuration are not done. Do not publish the API until issuer, audience, JWKS URL and database connection are set.
- Server synchronization is intentionally disabled (501) until device registration, membership validation, idempotent processing and conflict resolution are complete. The local outbox is durable but not yet uploaded.
- Stock movement ledger, transactional POS, payment provider integration, returns, receipts and complete reporting are not implemented.
- Product records are saved locally; the mobile app is not yet connected to a cloud sync worker.
- Flutter analysis, tests, API typecheck and device builds have not run in this environment. GitHub Actions is configured to run the checks on main.

## Next gates
1. Verify Managed Auth REST cookie/token flow on Android and iOS and configure production email delivery.
2. Complete device registration and outbox synchronization with idempotent domain transactions.
3. Implement stock ledger and transaction-safe stock level updates.
4. Complete POS, cash sessions, returns and receipt generation.
5. Add workspace switching, roles and permission management.
6. Run offline end-to-end tests and prepare Play Store / App Store builds.
