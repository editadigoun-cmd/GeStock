# GeStock implementation status

## Latest verified state
- Main only; current head at verification: `c47aa9896a80ee1e51a8c027ed7177d62b5f6204`.
- GitHub Actions quality run `44625717823`: backend typecheck/tests, Flutter analysis/tests, D1 migrations, API deployment/health, and authentication integration smoke test all passed.
- Android run `44625717701`: Flutter tests, release APK build, APK signature verification, checksum generation, release upload, and downloaded checksum verification passed.
- Admin Cloudflare deployment run `44617270299` succeeded. CI verified the unauthenticated admin path redirects to Cloudflare Access (HTTP 302).
- Cloudflare Access application is allowlisted for `editadigoun@gmail.com`, session 24 hours.
- D1 `gestock-db`: 27 application tables. Migration records 0001–0005 are present. User/business/product/sale counts were 0 at inspection; the auth tables are present.
- Active Cloudflare Workers: `gestock-api` and `gestock-admin`. The legacy auth-proxy Worker and its obsolete admin secret were removed. No Vercel deployment is configured.

## Cloudflare-native auth verified
- Registration/login, `/auth/me`, password change, new-password login, rejection of old password, logout revocation and rejection of revoked session were exercised against the deployed API in CI.
- Opaque 256-bit session tokens; only SHA-256 token digests stored; 30-day expiry; sessions revocable.
- PBKDF2-SHA-256 at 100,000 iterations with per-password salt (Workers runtime limit).
- Login throttling: 5 attempts/15 minutes per email+IP; registration throttling: 3/hour per IP.
- Admin API requires Cloudflare Access JWT, issuer/audience validation and allowlisted email.

## Remaining release blockers
1. The legacy external identity source has not been audited/exported. D1 has no users at the latest inspection; old identity data, if any, remains untouched and disconnected. Account migration/retention decision is required before deleting that data.
2. Admin dashboard is read-only. User/role CRUD, invitations, audit UI, full settings and recovery workflows remain incomplete.
3. Physical-device testing is still required for registration, login, password change, logout, business setup, offline/online sync and conflict recovery.
4. Email verification and email-delivered password recovery are not implemented.
5. Mobile features still incomplete: provider payments, cash sessions, returns/refunds, purchasing/receiving, credit, receipts/printing, warehouse transfers and conflict-resolution UI.
6. Production Play signing/AAB, iOS build and store publication have not been completed.

See [architecture](ARCHITECTURE.md) and [migration/rollback](AUTH_MIGRATION_ROLLBACK.md).
