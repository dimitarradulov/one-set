# OneSet account setup API

This Worker implements the `GET` and `PUT /v1/me/setup` contracts in [account setup](../docs/account-setup.md). PUT creates first completed setup using migration 002; reads use the existing Neon schema.

Install dependencies with `npm ci` in this directory (Node 22 or later). Run `npm run typecheck` and `npm test`, or the repository's `./scripts/validate.sh` after installing dependencies. Tests verify real signed session tokens and owner-scoped SQL against the applied schema in disposable PGlite Postgres. They do not contact a live Clerk instance or Neon database.

## Development configuration

Copy `.env.example` to the ignored `.dev.vars` for local Wrangler secrets. Set `DATABASE_URL` to a pooled URL for an isolated development Neon branch and `CLERK_JWT_KEY` to the PEM public key for the same Clerk instance used by the iOS app. No database or Clerk secret belongs in the app.

The committed `development` environment in `wrangler.jsonc` is configured for the app's Clerk development instance. For a different environment, configure:

- `CLERK_ISSUER`: the exact `https://YOUR_INSTANCE.clerk.accounts.dev` issuer.
- `CLERK_AUTHORIZED_PARTIES`: comma-separated permitted browser origins. Native session tokens can omit `azp`; a present `azp` must match.
- `PROGRAM_CATALOG_MAP`: a JSON object mapping the development database's numeric program IDs to the app's bundled program IDs, for example `{"YOUR_NUMERIC_PROGRAM_ID":"machine-full-body"}`. Inspect the branch's catalog IDs before setting it. This explicit mapping avoids assuming serial IDs or deriving identity from editable names. An unmapped selected program returns a retryable error.

Run `npm run dev` to use the development environment locally. Regenerate binding types with `npm run types`. For deployment, use `npx wrangler deploy --env development`; the deployed environment requires secrets named `DATABASE_URL` and `CLERK_JWT_KEY`. Production deployment remains outside this ticket's scope.

Debug builds already set the Xcode user-defined build setting `ONESET_API_BASE_URL` to the deployed development API. For another environment, set it to `https://YOUR_API_HOST` in the intended configuration, or pass it to `xcodebuild`. Release builds still require a production endpoint. `Config/Info.plist` exposes that public base URL to the HTTP adapter. Missing configuration shows Retry rather than treating an account as new. The app requires HTTPS; local Wrangler testing uses the API tests or an HTTPS development endpoint.

A returning-account fixture may be inserted on an isolated branch: create a `users` row with a development Clerk user ID and preferences, create an owned `user_programs` cycle referencing a mapped program, then set `users.active_user_program_id` to that cycle UUID. Do not seed or modify production training records. A user with no row or no cycles/active selection returns `setup: null`; broken existing cycle links return an error.

The JWT adapter follows [Clerk verification](https://clerk.com/docs/reference/backend/verify-token); the query uses [Neon's HTTP serverless driver](https://neon.com/docs/serverless/serverless-driver). Before deploying, verify the development issuer/key and program mapping with an actual app session. Automated tests establish the API contract, not the configuration of a live environment.

## Deployed development environment

As of 2026-10-05, `oneset-api-development` is deployed at [the development setup endpoint](https://oneset-api-development.dimitarradulovv.workers.dev/v1/me/setup). It uses the schema-only `oneset-development` Neon branch (`br-autumn-term-b1pjy8wc`) in the existing OneSet project. This branch has no automatic deletion date. Production data was not changed.

The isolated branch contains the ten bundled program identities and a Clerk test account with a completed setup fixture. Workout templates and training history are not seeded. The program mapping in the development environment matches this branch's IDs. Account enrollment writes remain a separate feature.

Live verification used a real native Clerk development session: a new account returned `200` with no setup; the same account after fixture insertion returned `200` with its saved preferences, program and cycle; missing or invalid tokens returned `401`. Supplying another owner in a query parameter did not change the authenticated account's response. These HTTP checks verify the deployed API; they do not establish a complete live iOS authentication journey.

Database credentials and the verification key are stored in Worker secret bindings. Public configuration is committed; credentials are not. Future deployments must preserve both secret bindings and use this branch's program mapping.

## Completed onboarding saves

`PUT /v1/me/setup` saves completed onboarding using the authenticated contract in [account setup](../docs/account-setup.md). Apply [migration 002](../docs/database/migrations/002_completed_setup.sql) before deploying this version. It adds a transactional first-completion function and leaves established cycles/history unchanged. Keep `PROGRAM_CATALOG_MAP` aligned with the bundled program IDs for both reads and writes. This change does not deploy the Worker or apply the migration automatically.

Migration 002 was applied to the deployed development database (`oneset` on `oneset-development`) on 2026-10-06 after rehearsal on a temporary child branch. First completion, safe retries and preservation of established records passed; the installed function and unchanged row counts were verified. The temporary branch was deleted. The updated Worker PUT handler has not been deployed by this migration task.

The completed-setup handler was deployed to `oneset-api-development` on 2026-10-06 as version `d0770628-d587-464d-a497-b5ad88578db2`, serving 100% of development traffic. Worker typechecking, all 14 API tests and the Wrangler deployment dry run passed. The deployed version retains `DATABASE_URL` and `CLERK_JWT_KEY`, with the existing development issuer, authorized party, catalog mapping and compatibility settings. Live GET/PUT requests without authentication and PUT with an invalid token returned `401 AUTH_REQUIRED`; POST returned `405 METHOD_NOT_ALLOWED`. Responses retained `Cache-Control: private, no-store`. A successful authenticated save still needs verification using an actual signed-in app session. Production was not deployed or modified.
