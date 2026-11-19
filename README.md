# GeStock

GeStock is an offline-first business management app for independent businesses and multi-company operators.

## Core workflows
- Mobile registration/login using Cloudflare Worker endpoints; secure session token storage on device.
- Multi-business setup, product catalogue, opening stock and adjustments, offline POS and durable sync.
- API, admin console and D1 data on Cloudflare.
- Admin console protected by Cloudflare Access and restricted to the administrator identity.

## Architecture
- Cloudflare Workers: API and web administration.
- Cloudflare D1: domain data, account password hashes and hashed sessions.
- Cloudflare Access: administrator SSO and API authorization.
- Flutter/Dart, Riverpod and SQLite on mobile.
- GitHub main branch only.

Cloudflare-native auth is implemented in source but awaiting deployment and live verification. No alternative hosting, external auth provider, or external database is intended. Legacy auth resources remain in a controlled rollback window and must be removed after the new APK/API/Admin are validated and adoption is confirmed.

## Repository
- mobile/: Flutter app.
- backend/: Worker API, D1 migrations and tests.
- admin/: web console.
- docs/: architecture/status.

## Run mobile
cd mobile; flutter pub get; flutter run

## Android
The latest test APK is published in the android-latest GitHub release, if that release workflow has completed. Verify the checksum before installing. Production signing/AAB and store publication remain separate release requirements.
