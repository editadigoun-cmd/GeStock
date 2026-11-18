# GeStock API — Cloudflare Workers

The API runs as a Cloudflare Worker, uses Hono for routing, Neon PostgreSQL through Cloudflare Hyperdrive, and Neon Managed Auth JWT verification.

## Cloudflare setup

1. In Cloudflare > Workers & Pages > Hyperdrive, create a configuration named `gestock-neon-postgres` pointing to the existing Neon project database `gestock` on branch `main`.
2. Disable Hyperdrive query caching: GeStock performs writes and transactional sync batches.
3. Replace the placeholder `hyperdrive[0].id` in `wrangler.jsonc` with the created Hyperdrive ID.
4. Add these Worker secrets in Settings > Variables and Secrets: `AUTH_ISSUER`, `AUTH_AUDIENCE`, `AUTH_JWKS_URL`.
5. Deploy from this directory with `npm install && npm run deploy`.

Never put Neon credentials or auth secrets in Git. Hyperdrive owns the database credentials; the Worker receives only its binding.

## Health check and mobile

After deployment, `GET /health` returns the API health response. Authenticated routes require a valid Neon Auth access token.

The mobile client must be built with `--dart-define=GESTOCK_API_URL=https://gestock-api.<your-workers-subdomain>.workers.dev` after deployment. Do not enable client sync until health, JWT validation, database access, and an end-to-end sync batch pass.
