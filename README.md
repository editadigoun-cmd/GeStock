# GeStock

GeStock is an offline-first business management app for independent businesses and multi-company operators.

## Core workflows
- Secure account access and native session storage.
- Multi-business setup and active workspace switching.
- Product catalogue: SKU/barcode, purchase/sale price, tax, stock threshold and edit (long-press a product).
- Opening inventory and stock adjustments with movement history.
- Offline-first POS: local sale, payment record, local stock deduction, durable sync outbox and sales history.
- Cloud API on Cloudflare Workers, D1 database, membership-scoped APIs and idempotent sync.
- Web admin: real health monitoring, business overview, recent sales, low-stock inventory and sync operations (read-only).

## Mandatory infrastructure
- Cloudflare Workers: API and web administration.
- Cloudflare D1: application database.
- Cloudflare Access: administrator protection.
- Cloudflare-native authentication: target for mobile accounts, sessions and API identity.
- GitHub: source and automation, main branch only.

No other hosting provider or external identity/database provider is part of the intended GeStock architecture. The authentication migration is a release blocker; do not remove the legacy identity service until the Cloudflare-native replacement, migration and rollback are tested.

## Stack
- Flutter / Dart, Riverpod, go_router and SQLite.
- TypeScript / Hono / Drizzle on Cloudflare Workers.
- Cloudflare D1 for domain data.
- Web admin deployed on Cloudflare Workers.

## Repository structure
- mobile/: Flutter application.
- backend/: Cloudflare Worker API, D1 migrations and tests.
- admin/: web admin console.
- docs/: architecture and implementation status.

## Run the mobile app
```
cd mobile
flutter pub get
flutter run
```

## Android release
The release-mode APK and SHA-256 file are published on the [android-latest GitHub Release](https://github.com/editadigoun-cmd/GeStock/releases/tag/android-latest). Verify the checksum before installation. Current builds are testing/sideloading builds; production store signing and AAB remain required.
