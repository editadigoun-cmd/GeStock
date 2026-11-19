# GeStock implementation status

## Latest main
- Latest migration work: Cloudflare-native auth source, D1 migrations 0004/0005 and admin/mobile integration. Main branch only.
- Current live D1 inspection on 19 Nov 2026: migrations 0001–0003 applied; app user/business/product/sale counts were 0; D1 contained 25 application tables at that inspection. New auth migrations are not yet confirmed live.
- Cloudflare Access app exists for gestock-admin.ccds22431.workers.dev, allow policy editadigoun@gmail.com, 24-hour session. Live unauthenticated redirect probe is still pending through CI.
- API Worker, Admin Worker and D1 are Cloudflare resources. Live request tests from this execution environment are blocked by external-request restrictions; use CI curl checks and real browser/device tests.

## Cloudflare auth source now implemented
- Registration/login and D1 sessions (opaque 256-bit token; only digest stored; 30-day expiry).
- PBKDF2-SHA-256 password hashes with 310,000 iterations and unique salt.
- Logout revocation, change-password, login rate limit (5 per 15 min per email/IP), registration rate limit (3 per hour/IP).
- Mobile client migrated to Worker API auth and secure storage; Admin switched to Cloudflare Access JWT; old admin Neon auth proxy routes/pages removed.
- Additive migrations 0004 (password/session tables) and 0005 (rate limits).

## Release blockers / limitations
1. CI must pass backend typecheck/tests and Flutter analyze/tests on current main. Deployment must apply 0004/0005 and verify API/D1 health.
2. Verify admin Access redirect and JWT-based admin API calls in browser; confirm only the allowlisted email can reach admin.
3. Test mobile registration, login, password change, logout, business setup, offline/online sync and conflict handling on a real device. Produce and checksum APK.
4. No email verification or password-recovery email system. This limitation must be addressed before broad public rollout.
5. Old Cloudflare auth-proxy Worker remains only for rollback until new API/Admin/APK validation and release adoption; remove it and any residual external auth secrets only after gates pass. Do not delete old identity data without an explicit migration/retention decision.
6. Mobile features still incomplete: provider payments, cash sessions, returns/refunds, purchasing/receiving, credit, receipts/printing, warehouse transfers and conflict-resolution UI.
7. Admin CRUD roles/invitations, audit UI, support, monetization and settings incomplete. Production Android signing/AAB, iOS and store release not done.
