# GeStock — implementation and release status

## Current source
- Main branch only; latest commit: `53d5e3dc85808653a0cc242f34934337c96c1bca`.
- Hosting: Cloudflare Workers + D1 + Cloudflare Access. Vercel and Neon are not used by the application or workflows.
- API Worker: `gestock-api`; admin Worker: `gestock-admin`.
- Cloudflare Access protects the admin console and restricts it to the configured administrator.
- CI is running for this source snapshot; do not call it production-ready until the latest run completes.

## Added in the current development pass
- Platform admin APIs and console controls for user/business suspension, settings, subscriptions, ad placements, support tickets and platform audit logs.
- Account suspension revokes active sessions; suspended businesses are now denied by backend business access checks.
- Email verification, resend verification, password-reset token flow, password-reset page and mobile recovery controls. Verification is enforced only when Resend is configured; email secrets are required for delivery.
- Mobile support request submission and request history.
- Offline synchronization status page, queued/failed/conflict counts, and retry action.
- Physical stock count workflow; count variances are recorded as stock adjustments and queued for sync.
- Automatic Android APK release build is enabled for main updates. Latest build is in progress.

## Verified before the current snapshot
- Previous main CI passed Flutter analysis/tests, backend typecheck/tests, D1 migrations, API health and auth smoke tests.
- Android APK signature and SHA-256 checks passed for an earlier release.
- Cloudflare Access anonymous request was verified to redirect to login.
- Backend dependency audit had zero vulnerabilities; admin audit had five moderate findings in the build toolchain and no high-severity findings at the last audit.

## Remaining items / external setup
1. **Email delivery:** configure `RESEND_API_KEY`, `EMAIL_FROM`, and `APP_BASE_URL` as Worker secrets/vars, then test verification, invitation, and recovery emails with a real address.
2. **Ads:** Ad placements are configurable in admin, but the mobile Ad SDK and valid AdMob app/unit IDs are not integrated/configured.
3. **Subscriptions/payments:** admin can assign plans manually; purchase flow, provider verification, app-store billing and entitlements enforcement remain incomplete.
4. **Role permissions:** employee membership/roles exist, but permission enforcement across every API workflow requires a full role-by-role audit.
5. **Inventory:** physical count is implemented; warehouse transfer workflow remains to be implemented and tested.
6. **Receipts/printing:** receipt formatting and device printing remain incomplete.
7. **Mobile validation:** physical Android testing is required for registration, email verification, password recovery, offline/online sync, stock count, sales, returns, cash sessions, purchasing and support.
8. **iOS:** build, signing and App Store publication have not been completed.
9. **Play Store:** Play Console setup, production signing/AAB, listing, policy disclosures and publication remain external release tasks.
10. **Legacy identity:** the previous identity-provider data was not audited/exported; it remains untouched and disconnected.
11. **GitHub metadata:** repository Homepage still contains an obsolete Vercel URL. Clear it in repository Settings; the GitHub connector available here cannot edit repository metadata.

## Release rule
Only mark GeStock production-ready after the latest CI and Android build pass, the email/ads/payment secrets are configured where needed, and physical-device validation is complete.
