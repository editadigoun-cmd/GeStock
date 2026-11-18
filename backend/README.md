# GeStock API — Cloudflare Workers

The API runs as a Cloudflare Worker, uses Hono for routing, Neon PostgreSQL through Cloudflare Hyperdrive, and Neon Managed Auth JWT verification.

## Cloudflare setup

1. Create the Hyperdrive configuration `gestock-neon-main` for the existing Neon database `gestock` on branch `main`.
2. Keep Hyperdrive query caching disabled.
3. The Hyperdrive ID and Neon Auth issuer/JWKS URL are configured in `wrangler.jsonc`.
4. In GitHub repository Settings > Secrets and variables > Actions, add `CLOUDFLARE_API_TOKEN` with a Cloudflare API token that can deploy Workers scripts.
5. A push to `main` runs type checks and then deploys the API to Cloudflare. Without the secret, deployment is skipped.

Never put Neon database credentials or API tokens in Git. Hyperdrive owns the database credentials; the Worker receives only its binding.

## Health check and mobile

After deployment, `GET /health` returns the API health response. Authenticated routes require a valid Neon Auth access token.

The mobile client must be built with `--dart-define=GESTOCK_API_URL=https://gestock-api.<your-workers-subdomain>.workers.dev` after deployment. Do not enable client sync until health, JWT validation, database access, and an end-to-end sync batch pass.
