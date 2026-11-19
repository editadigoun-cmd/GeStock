# GeStock API — Cloudflare Workers

Production API and authentication run on Cloudflare Workers. Business data and identity/session records are stored in Cloudflare D1 (gestock-db). No Vercel or Neon service is required by this repository.

## Cloudflare-native authentication
- Registration and login: POST /auth/register and POST /auth/login.
- Sessions use random 256-bit opaque tokens; only SHA-256 digests are stored in D1. Tokens expire after 30 days and logout revokes them.
- Passwords are salted PBKDF2-SHA-256 (310,000 iterations).
- GET /auth/me validates a session. POST /auth/change-password requires the current password and revokes other sessions.
- Email verification and email-based password recovery are not implemented yet. Mobile users cannot self-recover passwords; the admin console is separately protected by Cloudflare Access.
- Business API routes require D1-backed session tokens. Admin routes require a Cloudflare Access JWT with the configured issuer/audience and exact allowlisted email.

## D1 migrations and rollback
Migration 0004 is additive: password fields and session tables only. It does not delete business records. Rollback redeploys the previous Worker version while retaining the additive D1 migration; never drop tables or reset D1. On 19 November 2026, D1 was checked live: migrations 0001–0003 were applied and business/user/product/sale counts were zero. Migration 0004 must be confirmed by CI after deploy. Existing external identity accounts were not imported; users must register again. Keep legacy infrastructure during a controlled rollback window, then decommission only after confirming no released client depends on it.

## Deployment
GitHub Actions secret CLOUDFLARE_API_TOKEN must authorize Workers and D1. Push main: tests run, migration applies, API deploys, and health checks verify /health and /health/d1. Admin deploy uses Cloudflare Workers/Vinext and verifies that unauthenticated requests are redirected by Cloudflare Access before trusting Access identity headers.

## Features
Businesses, products, stock, sales, and offline idempotent sync; read-only admin overview, business/sales/inventory/sync/user directory. External payment providers, email verification/recovery, advanced role/invitation management, subscriptions, advertising, support and complete settings/audit tools remain unfinished.
