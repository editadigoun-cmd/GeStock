# Authentication migration and rollback

## Current state
- Mobile/API accounts and sessions use Cloudflare D1 and the GeStock Worker API.
- Admin console is gated by Cloudflare Access; the API verifies the Access JWT issuer, audience and allowlisted email.
- Migrations 0004 and 0005 are additive. No existing domain table or record is deleted.
- CI has verified registration, login, session validation, password change, old-password rejection, logout and revoked-session rejection against the deployed API.
- The old authentication proxy Worker and its unused admin Worker secret were removed. Current source/workflows do not call them.

## Data preservation
Production D1 was inspected: 26 application tables, migration records 0001–0005, and zero users/businesses/products/sales at that inspection. No D1 domain records were modified by auth migration. The previous external identity source was not audited/exported; any data there is untouched and disconnected. Do not delete that external data until its owner approves an export/retention decision.

## Rollback
1. If the new API has an incident, deploy a known-good Cloudflare API Worker version from the verified main history; do not restore the old auth proxy.
2. Keep D1 migrations 0004/0005 and all application data. Never drop `auth_sessions`, `auth_rate_limits`, or `app_users` during rollback.
3. Roll back admin Worker only to a version that still enforces Cloudflare Access. Do not expose the admin host or bypass Access.
4. Verify `/health`, `/health/d1`, invalid-login status, and Admin Access redirect before declaring rollback complete.
5. Re-deploy the forward fix from `main` after repair and rerun the auth smoke test.

## Migration completion criteria
- CI success on main and remote D1 migrations confirmed.
- API health and auth end-to-end checks pass.
- Admin Access redirect and JWT-protected API pass.
- Mobile release APK checksum verified.
- Physical-device workflow tests pass.
- Legacy identity data audited and retention/export decision recorded.

## Current outstanding items
The physical-device tests, admin CRUD/recovery, email verification/recovery delivery, and legacy identity-data audit are not yet complete. The Cloudflare-native authentication runtime is live and CI-tested; broad public rollout is not yet approved.
