# GeStock implementation status

## Latest verified state
- Current main: `6dbc100950952c275076e509033f551efdfe0afc`; GitHub branch list contains only `main`.
- Quality run `44638384366` passed on the current main commit: Flutter analysis/tests, backend typecheck/tests, D1 migrations, API deployment/health and deployed auth smoke test.
- Admin deployment run `44638031895` passed on `c5fbc27`: Vinext compatibility, Cloudflare build, high-severity dependency audit, deployment and Access edge redirect verification.
- Current Cloudflare Workers: `gestock-api` and `gestock-admin`; no GeStock auth-proxy Worker remains.
- API Worker deployed from current main at `2026-11-19T23:33:27Z`; Admin Worker source remains unchanged since its successful deployment at `2026-11-19T23:30:14Z`.
- Cloudflare Access app `GeStock Admin Console` protects `gestock-admin.ccds22431.workers.dev`, allows `editadigoun@gmail.com`, and has a 24-hour session. CI's anonymous probe returned HTTP 302 to the Cloudflare Access login domain.
- Live D1 inspection: `gestock-db` has 29 SQLite tables total (26 application tables plus D1/system tables); migration records 0001–0005 exist; `app_users`, `businesses`, `products`, and `sales` are all empty. Auth tables `auth_sessions` and `auth_rate_limits` exist.
- Cloudflare-only code/workflows search found no Vercel or Neon references. The legacy auth proxy Worker and obsolete Admin secret were removed.
- **Residual GitHub metadata:** the repository's Homepage setting still points to an old Vercel URL (`gestock-admin.vercel.app`). It is not used by code or deployment. The available GitHub integration can write repository files but cannot update repository settings; the Homepage field must be cleared in GitHub repository Settings. Do not use that URL.
- Android release build run `44625717701` passed from mobile commit `c47aa989`; the mobile source has not changed since. The release APK is `GeStock.apk`, 54,617,511 bytes, with release SHA-256 `e7fc53a2baf4f335efbfd7aeb51d5158c40e4090bbb9a39b984a74a2bc62b704`. GitHub release metadata reports the same digest, and CI verified the downloaded APK against its checksum.

## Cloudflare-native auth verified
- Registration/login, `/auth/me`, password change, new-password login, rejection of old password, logout revocation and rejection of revoked session were exercised against the deployed API in CI.
- Opaque 256-bit session tokens; only SHA-256 token digests stored; 30-day expiry; sessions revocable.
- PBKDF2-SHA-256 at 100,000 iterations with per-password salt (Cloudflare Workers limit).
- Login throttling: 5 attempts/15 minutes per email+IP; registration throttling: 3/hour per IP; stale rate-limit records are cleaned after 24 hours.
- Admin API requires Cloudflare Access JWT, issuer/audience validation and allowlisted email.

## Dependency security
- Backend audit: 0 vulnerabilities after upgrading Drizzle ORM to 0.45.4 and Zod to 4.6.7.
- Admin high-severity audit gate passes after upgrading Next.js to 16.4.6, overriding PostCSS to 8.5.23, and applying compatible dependency fixes. Five moderate findings remain in the build tool chain (including fflate ZIP64 parsing); forcing a breaking Vinext dependency change was not applied.

## Remaining release blockers
1. The previous external identity data was not audited/exported. D1 has no users at the latest inspection; any old identity data remains untouched and disconnected. Preserve it until export/retention is verified; no legacy provider code or proxy is active.
2. Admin dashboard remains read-only. User/role CRUD, invitations, audit UI, full settings and recovery workflows remain incomplete.
3. Physical-device testing is still required for registration, login, password change, logout, business setup, offline/online sync and conflict recovery.
4. Email verification and email-delivered password recovery are not implemented.
5. Mobile features still incomplete: provider payments, cash sessions, returns/refunds, purchasing/receiving, credit, receipts/printing, warehouse transfers and conflict-resolution UI.
6. Production Play signing/AAB, iOS build and store publication have not been completed.
7. Clear the stale GitHub Homepage setting as noted above.

See [architecture](ARCHITECTURE.md) and [migration/rollback](AUTH_MIGRATION_ROLLBACK.md).
