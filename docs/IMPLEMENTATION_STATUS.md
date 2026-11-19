# GeStock implementation status

## Latest verified state
- Current main: `c5fbc27bce76efcca259821b1c1998562f81fa20`; branch list contains only `main`.
- Quality run `44638031890` passed: Flutter analysis/tests, backend typecheck/tests, dependency high-severity audit, D1 migrations, API deploy/health and deployed auth smoke test.
- Admin deployment run `44638031895` passed: Next 16.4.6 compatibility check, Cloudflare build, high-severity dependency gate, deployment and Cloudflare Access redirect verification.
- API Worker deployed at `2026-11-19T23:29:45Z`; Admin Worker deployed at `2026-11-19T23:30:26Z`.
- Admin Access application is allowlisted for `editadigoun@gmail.com`, 24-hour session; unauthenticated edge probe redirected to Access.
- D1 `gestock-db`: 26 application tables and migration records 0001–0005. User/business/product/sale/session counts were 0 at latest inspection.
- Only `gestock-api` and `gestock-admin` Workers remain active. The legacy auth proxy Worker and obsolete admin secret were removed.
- Current source and workflows have no external identity/database/hosting-provider references. Code search for the former provider/host names returned zero results.
- Android release build run `44625717701` passed; APK and SHA-256 verification passed. Mobile source is unchanged since that build.

## Cloudflare-native auth verified
- Registration/login, `/auth/me`, password change, new-password login, rejection of old password, logout revocation and rejection of revoked session were exercised against the deployed API in CI.
- Opaque 256-bit session tokens; only SHA-256 token digests stored; 30-day expiry; sessions revocable.
- PBKDF2-SHA-256 at 100,000 iterations with per-password salt.
- Login throttling: 5 attempts/15 minutes per email+IP; registration throttling: 3/hour per IP; stale rate-limit records are cleaned after 24 hours.
- Admin API requires Cloudflare Access JWT, issuer/audience validation and allowlisted email.

## Dependency security
- Backend audit: 0 vulnerabilities after upgrading Drizzle ORM to 0.45.4 and Zod to 4.6.7.
- Admin high-severity audit gate passes after upgrading Next.js to 16.4.6, overriding PostCSS to 8.5.23, and applying compatible dependency fixes. Five moderate findings remain in the build tool chain (including fflate ZIP64 parsing); forcing the breaking downgrade of vinext was not applied.

## Remaining release blockers
1. The previous external identity source has not been audited/exported. D1 has no users at the latest inspection; any legacy identity data remains untouched and disconnected. Decide account migration/retention before deleting that data.
2. Admin dashboard remains read-only. User/role CRUD, invitations, audit UI, full settings and recovery workflows remain incomplete.
3. Physical-device testing is still required for registration, login, password change, logout, business setup, offline/online sync and conflict recovery.
4. Email verification and email-delivered password recovery are not implemented.
5. Mobile features still incomplete: provider payments, cash sessions, returns/refunds, purchasing/receiving, credit, receipts/printing, warehouse transfers and conflict-resolution UI.
6. Production Play signing/AAB, iOS build and store publication have not been completed.

See [architecture](ARCHITECTURE.md) and [migration/rollback](AUTH_MIGRATION_ROLLBACK.md).
