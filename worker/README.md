# OneSet Worker and program catalog

This Worker implements the `GET` and `PUT /v1/me/setup` contracts in [account setup](../docs/account-setup.md), authenticated catalog delivery, and the founder's catalog publisher API. Program content lives in [catalog](catalog/), is previewed and validated before publication, and is applied atomically to Neon. Setup uses persistent authoring keys from migration 003 instead of a deployment-time per-program map.

Install dependencies with `npm ci` in this directory (Node 22 or later). Run `npm run typecheck` and `npm test`, or the repository's `./scripts/validate.sh` after installing dependencies. Tests verify real signed session tokens and owner-scoped SQL against the applied schema in disposable PGlite Postgres. They do not contact a live Clerk instance or Neon database.

## Development configuration

Copy `.env.example` to the ignored `.dev.vars` for local Wrangler secrets. Set `DATABASE_URL` to a pooled URL for an isolated development Neon branch, `CLERK_JWT_KEY` to the PEM public key for the same Clerk instance used by the iOS app, and `CATALOG_PUBLISH_TOKEN` to a random maintenance secret. The publisher token is separate from Clerk sessions and is never added to the iOS app. For a deployed Worker, set that binding with `npx wrangler secret put CATALOG_PUBLISH_TOKEN --env development`.

The committed `development` environment in `wrangler.jsonc` is configured for the app's Clerk development instance. For a different environment, configure:

- `CLERK_ISSUER`: the exact `https://YOUR_INSTANCE.clerk.accounts.dev` issuer.
- `CLERK_AUTHORIZED_PARTIES`: comma-separated permitted browser origins. Native session tokens can omit `azp`; a present `azp` must match.

The catalog publisher requires explicit environment-scoped process variables. Point them at the intended API and use the same maintenance token configured as the Worker secret:

```sh
export ONESET_CATALOG_API_DEVELOPMENT=https://oneset-api-development.dimitarradulovv.workers.dev
export ONESET_CATALOG_PUBLISH_TOKEN_DEVELOPMENT=YOUR_RANDOM_PUBLISHER_TOKEN
npm run catalog -- preview --environment development --source catalog
# Review the printed changes and .oneset-catalog-preview.json before publishing.
npm run catalog -- publish --environment development --source catalog
```

Preview checks stable keys, references, complete exercise guidance, positive rep bounds and order. It rejects omitted previously published programs, workouts, slots or exercises. An exercise guidance edit lists every current program use as `Program name (program-key)`, so programs with the same display name remain distinct. Slot rep ranges are authored separately in each workout template; shared exercise defaults do not overwrite them.

Keep the authoring key unchanged when editing a program, workout, exercise, or slot. Renaming an item and changing compatible prescription fields preserves its identity. A slot key cannot be reassigned to a different exercise or workout; give a genuinely different slot a new key through the structural-change workflow.

The review file binds the exact source and backend fingerprint to the chosen environment; rerun preview after any source or backend change. Keep review output private to your local working tree. A stale preview is rejected without changing the catalog, and a failed database transaction leaves the previous snapshot in place. Retrying the same successful publication is safe.

From `worker/`, correct a publication by restoring the desired catalog files from Git, then preview and publish them as a new publication:

```sh
git restore --source <commit-with-correct-content> -- catalog
npm run catalog -- preview --environment development --source catalog
# Confirm the changes and every affected program, then:
npm run catalog -- publish --environment development --source catalog
```

This republishes catalog text only. It does not rewind cycles, preferences, completion marks, completed records, or prescriptions already captured by sessions. Existing app installs receive the corrected snapshot on their normal catalog refresh and retain their cached copy while offline.

Run `npm run dev` to use the development environment locally. Regenerate binding types with `npm run types`. For deployment, use `npx wrangler deploy --env development`; the deployed environment requires secrets named `DATABASE_URL` and `CLERK_JWT_KEY`. Production deployment remains outside this ticket's scope.

Debug builds already set the Xcode user-defined build setting `ONESET_API_BASE_URL` to the deployed development API. For another environment, set it to `https://YOUR_API_HOST` in the intended configuration, or pass it to `xcodebuild`. Release builds still require a production endpoint. `Config/Info.plist` exposes that public base URL to the HTTP adapter. Missing configuration shows Retry rather than treating an account as new. The app requires HTTPS; local Wrangler testing uses the API tests or an HTTPS development endpoint.

A returning-account fixture may be inserted on an isolated branch: create a `users` row with a development Clerk user ID and preferences, create an owned `user_programs` cycle referencing a mapped program, then set `users.active_user_program_id` to that cycle UUID. Do not seed or modify production training records. A user with no row or no cycles/active selection returns `setup: null`; broken existing cycle links return an error.

The JWT adapter follows [Clerk verification](https://clerk.com/docs/reference/backend/verify-token); the query uses [Neon's HTTP serverless driver](https://neon.com/docs/serverless/serverless-driver). Before deploying a migration-aware version, verify the development issuer/key and stable authoring keys with an actual app session. Automated tests establish the API contract, not the configuration of a live environment.

## Deployed development environment

As of 2026-10-05, `oneset-api-development` is deployed at [the development setup endpoint](https://oneset-api-development.dimitarradulovv.workers.dev/v1/me/setup). It uses the schema-only `oneset-development` Neon branch (`br-autumn-term-b1pjy8wc`) in the existing OneSet project. This branch has no automatic deletion date. Production data was not changed.

The isolated branch contains the ten bundled program identities and a Clerk test account with a completed setup fixture. Workout templates and training history are not seeded. Account identity provisioning is deployed in Worker version `31bad2ca-8d69-4195-8c3c-b124b0bf0466` (2026-10-05) and occurs on authenticated setup lookup. Completed-setup enrollment writes remain a separate feature.

Live verification used a real native Clerk development session: a new account returned `200` with no setup; the same account after fixture insertion returned `200` with its saved preferences, program and cycle; missing or invalid tokens returned `401`. Supplying another owner in a query parameter did not change the authenticated account's response. These HTTP checks verify the deployed API; they do not establish a complete live iOS authentication journey.

Database credentials and the verification key are stored in Worker secret bindings. Public configuration is committed; credentials are not. Future deployments must preserve the database and Clerk secret bindings. Migration 003 persists authoring keys, so publishing a program does not require a deployment-time program map.

The identity-provisioning update passed signed-token API tests against disposable PGlite, including first lookup, concurrent lookup, preserved preferences and retry after lookup failure. The deployed version rejects missing/invalid tokens with `401`. Authenticated live provisioning still needs verification with an actual app session; no live Clerk token or direct Neon connection was available for this update.

## Completed onboarding saves

`PUT /v1/me/setup` saves completed onboarding using the authenticated contract in [account setup](../docs/account-setup.md). Apply [migration 002](../docs/database/migrations/002_completed_setup.sql) for onboarding writes and [migration 003](../docs/database/migrations/003_catalog_publication.sql) for stable authoring keys, publication and catalog reads. Setup resolves authoring keys directly against `workout_programs`; no deployment-time program map is required.

Migration 002 was applied to the deployed development database (`oneset` on `oneset-development`) on 2026-10-06 after rehearsal on a temporary child branch. First completion, safe retries and preservation of established records passed; the installed function and unchanged row counts were verified. The temporary branch was deleted. The updated Worker PUT handler has not been deployed by this migration task.

The completed-setup handler was deployed to `oneset-api-development` on 2026-10-06 as version `d0770628-d587-464d-a497-b5ad88578db2`, serving 100% of development traffic. Worker typechecking, all 14 API tests and the Wrangler deployment dry run passed. That historical version retained `DATABASE_URL` and `CLERK_JWT_KEY`, with the existing development issuer, authorized party, and compatibility settings; at that point it still used a `PROGRAM_CATALOG_MAP`. Migration 003 and the catalog-aware Worker replace that mapping with persistent authoring keys. Live GET/PUT requests without authentication and PUT with an invalid token returned `401 AUTH_REQUIRED`; POST returned `405 METHOD_NOT_ALLOWED`. Responses retained `Cache-Control: private, no-store`. A successful authenticated save still needs verification using an actual signed-in app session. Production was not deployed or modified.

## Catalog API

`GET /v1/catalog` requires a valid Clerk session bearer token and returns one complete publication snapshot with stable authoring keys, program display fields, workout order, slot rep targets and shared exercise technique, stopping, warm-up and rest guidance. It returns an `ETag`; send it as `If-None-Match` to receive `304` when the publication is unchanged. The same snapshot is available at `/v1/catalog/programs`, `/v1/catalog/exercises`, and `/v1/catalog/programs/{key}`. Responses are private and do not mix rows across publications.

`POST /v1/maintenance/catalog/preview` and `/publish` require the separate `CATALOG_PUBLISH_TOKEN` bearer secret. Ordinary Clerk account tokens are not accepted. Preview reports additions, updates and affected programs without database mutation. Publish requires its preview ID and source/backend fingerprints, then invokes the database transaction. A changed source or backend requires a new preview; an identical retry is safe. Invalid input returns `422 INVALID_CATALOG`, a stale preview returns `409 STALE_PREVIEW`, an ordinary user token receives `403 FORBIDDEN`, and a database failure returns `503 TEMPORARY_FAILURE` while preserving the prior snapshot.
