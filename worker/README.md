# OneSet account setup API

This Worker implements the read-only `GET /v1/me/setup` contract in [account setup](../docs/account-setup.md). It reads the existing Neon schema; no migration or training-data writes are required.

Install dependencies with `npm ci` in this directory (Node 22 or later). Run `npm run typecheck` and `npm test`, or the repository's `./scripts/validate.sh` after installing dependencies. Tests verify real signed session tokens and owner-scoped SQL against the applied schema in disposable PGlite Postgres. They do not contact a live Clerk instance or Neon database.

## Development configuration

Copy `.env.example` to the ignored `.dev.vars` for local Wrangler secrets. Set `DATABASE_URL` to a pooled URL for an isolated development Neon branch and `CLERK_JWT_KEY` to the PEM public key for the same Clerk instance used by the iOS app. No database or Clerk secret belongs in the app.

Replace the placeholders in `wrangler.jsonc`:

- `CLERK_ISSUER`: the exact `https://YOUR_INSTANCE.clerk.accounts.dev` issuer.
- `CLERK_AUTHORIZED_PARTIES`: comma-separated permitted browser origins. Native session tokens can omit `azp`; a present `azp` must match.
- `PROGRAM_CATALOG_MAP`: a JSON object mapping the development database's numeric program IDs to the app's bundled program IDs, for example `{"YOUR_NUMERIC_PROGRAM_ID":"machine-full-body"}`. Inspect the branch's catalog IDs before setting it. This explicit mapping avoids assuming serial IDs or deriving identity from editable names. An unmapped selected program returns a retryable error.

Run `npm run dev` to use local Wrangler. A deployed development Worker needs the same variables and Wrangler secrets for `DATABASE_URL` and `CLERK_JWT_KEY`. Deployment is outside this ticket's production scope.

For the app, set the Xcode user-defined build setting `ONESET_API_BASE_URL` to `https://YOUR_DEVELOPMENT_API_HOST` in both configurations, or pass it to `xcodebuild`. `Config/Info.plist` exposes that public base URL to the HTTP adapter. Missing configuration shows Retry rather than treating an account as new. The app requires HTTPS; local Wrangler testing uses the API tests or an HTTPS development endpoint.

A returning-account fixture may be inserted on an isolated branch: create a `users` row with a development Clerk user ID and preferences, create an owned `user_programs` cycle referencing a mapped program, then set `users.active_user_program_id` to that cycle UUID. Do not seed or modify production training records. A user with no row or no cycles/active selection returns `setup: null`; broken existing cycle links return an error.

The JWT adapter follows [Clerk verification](https://clerk.com/docs/reference/backend/verify-token); the query uses [Neon's HTTP serverless driver](https://neon.com/docs/serverless/serverless-driver). Before deploying, verify the development issuer/key and program mapping with an actual app session. Automated tests establish the API contract, not the configuration of a live environment.
