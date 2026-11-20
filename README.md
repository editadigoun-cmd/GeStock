# GeStock

GeStock is an offline-first business management application for independent businesses and multi-company operators.

## Core workflows
- Cloudflare-native mobile registration and login with secure token storage.
- Multi-business setup, product catalogue, stock movements, offline POS and durable synchronization.
- Cloudflare Workers API and web administration; Cloudflare D1 for application data.
- Administrator console protected at the edge by Cloudflare Access.

## Architecture
- Cloudflare Workers: API and web administration.
- Cloudflare D1: domain data, password hashes, hashed sessions and rate limits.
- Cloudflare Access: administrator SSO and API authorization.
- Flutter/Dart, Riverpod and SQLite on mobile.
- GitHub main branch only.

## Verification
The latest main CI passed backend tests/typecheck and Flutter analysis/tests. Cloudflare D1 migrations, API deployment and health checks passed; the authentication smoke test is running. The latest Android release build passed signature and SHA-256 checks. See [implementation status](docs/IMPLEMENTATION_STATUS.md) and the [migration/rollback plan](docs/AUTH_MIGRATION_ROLLBACK.md).

## Current limitations
The admin console is a monitoring/read-only dashboard. User/role CRUD, invitations, email verification/password recovery, warehouse transfers, ad integration, subscription billing, physical-device testing and store publication are not complete. Printable PDF sales receipts have been added; physical printer validation remains. Do not treat this as a production-ready public release yet.

## Repository
- mobile/: Flutter app.
- backend/: Cloudflare Worker API, D1 migrations and tests.
- admin/: Cloudflare Worker web console.
- docs/: architecture, status and migration/rollback plan.

## Run mobile
```sh
cd mobile
flutter pub get
flutter run
```

## Android
The latest APK is published in the `android-latest` GitHub release. Verify its accompanying SHA-256 file before installing. Play Store production signing/AAB and store publication are separate release requirements.
