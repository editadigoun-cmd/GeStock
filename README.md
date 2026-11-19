# GeStock

GeStock is an offline-first business management app for independent businesses and multi-company operators.

## Core workflows
- Neon Auth sign-in and secure native session storage.
- Multi-business setup and active workspace switching.
- Product catalogue: SKU/barcode, purchase/sale price, tax, stock threshold and edit (long-press a product).
- Opening inventory and stock adjustments with movement history.
- Offline-first POS: local sale, payment record, local stock deduction, durable sync outbox and sales history.
- Cloud API on Cloudflare Workers, D1 database, membership-scoped APIs and idempotent sync.
- Web admin: real health monitoring, business overview, recent sales, low-stock inventory and sync operations (read-only).

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
\`\`\`
cd mobile
flutter pub get
flutter run
\`\`\`

## Android release
The release-mode APK and SHA-256 file are published on [the android-latest GitHub Release](https://github.com/editadigoun-cmd/GeStock/releases/tag/android-latest). This is not yet a signed Play Store bundle.

See docs/ARCHITECTURE.md and docs/IMPLEMENTATION_STATUS.md for details.
