# GeStock

GeStock is an offline-first business management app for independent businesses and multi-company operators.

## Current core workflows
- Neon Auth sign-in and secure native session storage.
- Multi-business setup and active workspace switching.
- Product catalogue with SKU/barcode, purchase/sale price and stock threshold.
- Opening inventory and stock adjustments with movement history.
- Offline-first POS: local sale, payment record, local stock deduction, durable sync outbox and sales history.
- Cloud API on Cloudflare Workers, D1 database, membership-scoped APIs and idempotent sync.
- Web admin: real health monitoring, platform counts and business list (read-only).

## Stack
- Flutter / Dart, Riverpod, go_router and SQLite.
- TypeScript / Hono / Drizzle on Cloudflare Workers.
- Cloudflare D1 for domain data; Neon Managed Auth for identity.
- Next.js/Vinext admin deployed on Cloudflare Workers.

Neon domain-data migration is not verified; existing Neon data is preserved. D1 was empty at the last verification.

## Repository structure
- mobile/: Flutter application.
- backend/: Cloudflare Worker API, D1 migrations and tests.
- admin/: web admin console.
- docs/: architecture and implementation status.

## Run the mobile app
```bash
cd mobile
flutter pub get
flutter run
```

Build an APK from CI: the Android workflow publishes a release-mode APK with its SHA-256 checksum to the android-latest GitHub Release. It is not yet a signed Play Store bundle.

See docs/ARCHITECTURE.md and docs/IMPLEMENTATION_STATUS.md for details.
