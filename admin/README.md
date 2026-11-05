# Private catalog dashboard

The dashboard in this directory is a server-rendered Astro site for laptop catalog maintenance. It reads the complete published source through the protected maintenance API and creates or edits programs, ordered workout templates, display metadata, exercise slots, and shared exercise guidance in native HTML forms. Programs, workout templates, and slots can be removed and restored while retaining their source identities. The server validates the complete submitted source against the current publication before review and explicit publication. Unpublished edits stay within the current visit; no drafts are saved in browser storage. It is deployed to `https://oneset-catalog-dashboard.dimitarradulovv.workers.dev` behind hostname-specific Cloudflare Access. Preview URLs and custom domain routes are disabled.

After database publication, the dashboard synchronizes the exact retained publication source to the configured GitHub branch and regenerates the bundled Swift catalog with the same pure generator used by the catalog CLI. Repository failure remains visible and retryable against that publication; stale or competing work cannot overwrite a newer source. Publication history supports reconciled corrections while retaining later identities and training records. The dashboard uses the configured Cloudflare Access hostname with preview URLs and alternate routes disabled.
## Local development and checks

Use Node 22 or later:

```sh
npm ci
npm run dev
npm run check
npm run build
npm test
```

The Worker request integration uses signed test tokens and an isolated PGlite database to exercise the real maintenance source-read, preview, publish, history, and repository-sync handlers. Checks cover complete program creation, program and shared exercise editing, workout structure and explicit removal/restoration, historical correction, validation feedback, Access and origin rejection, stale review, rollback, retry identity, synchronization conflicts and partial failure, metadata and stable identity preservation, and the resulting app-facing catalog. Browser journeys use the installed Chrome executable; set `DASHBOARD_CHROME_BIN` when it is elsewhere. Local signed-token checks do not verify deployed Access or GitHub credentials.

## Cloudflare Access setup

Use the Cloudflare Zero Trust dashboard on the Free plan before adding a public route:

1. Add the One-time PIN identity provider, which delivers a sign-in code to the email address.
2. Create a self-hosted Access application for `oneset-catalog-dashboard.dimitarradulovv.workers.dev`. Add one Allow policy whose include rule is the exact approved founder email, `dimitarradulovv@gmail.com`. Do not add an email-domain or everyone rule.
3. Set both the application's session duration and the global session duration to one month.
4. Record the application's Audience (AUD) tag and the Cloudflare Zero Trust team domain.
5. Set `ACCESS_TEAM_DOMAIN`, `ACCESS_AUDIENCE`, and `ACCESS_APPROVED_EMAIL` in `admin/wrangler.jsonc` and the corresponding development values in `worker/wrangler.jsonc`. The dashboard forwards the signed Access assertion to the API; the API independently checks its signature, issuer, audience, expiration, and exact allowed identity before returning the full source document.
6. Keep `preview_urls` disabled. The configured `workers.dev` hostname is the only dashboard route and is protected by the hostname-specific Access application. Do not attach alternate hostnames or custom routes without creating corresponding Access protection first.
7. Deploy the API Worker and then the dashboard Worker from their own directories. The dashboard hostname is enabled in its config only after the Access application is ready:

   ```sh
   cd worker
   npm ci
   npx --no-install wrangler deploy --env development
   cd ../admin
   npm ci
   npm run build
   ../worker/node_modules/.bin/wrangler deploy
   ```

The API still needs its existing `DATABASE_URL`, `CLERK_JWT_KEY`, and `CATALOG_PUBLISH_TOKEN` secrets. Apply [migration 011](../docs/database/migrations/011_catalog_repository_sync.sql) to the intended development database before deploying the Worker handler. Set the same publisher token as a server-side secret on the dashboard Worker with `npx wrangler secret put CATALOG_PUBLISH_TOKEN`; never add it to `wrangler.jsonc`, client markup, or browser code. The dashboard reads the configured `CATALOG_API_BASE_URL` and `CATALOG_ENVIRONMENT`; both values are server-side Worker variables. The repository target is also explicit in `wrangler.jsonc` (`CATALOG_REPOSITORY_OWNER`, `CATALOG_REPOSITORY_NAME`, and `CATALOG_REPOSITORY_BRANCH`). Add a fine-grained GitHub token as the dashboard-only secret `CATALOG_REPOSITORY_TOKEN`, scoped to that repository with Contents read/write access. Keep the token server-side; it is never sent to the browser. Repository writes are disabled unless the catalog environment is exactly `development`; its configured target must stay bound to the development API until the complete parent scope is delivered and validated. The deployment must point to the intended API and repository explicitly. If the database cannot be read, the page returns an unavailable response rather than rendering an empty catalog.

Each GitHub update creates a commit on the configured branch with only `worker/catalog/` source files, the publication marker, and `OneSet/Services/Catalog/BundledProgramCatalog.swift`. It bases the commit on the latest branch head and uses a non-forced ref update; concurrent repository edits cause a retryable conflict instead of replacing unrelated work. Before applying the ref update, the server verifies that the same publication is still current. A failed export does not undo the database publication. The page states that distinction and retries the retained publication ID. Repeating a successful sync sees the committed marker and does not create another commit. A newer database publication invalidates stale synchronization work.

Every Astro Action verifies the signed Cloudflare Access assertion and requires a same-origin `POST` with an HTML form content type. The server uses the publisher token for the existing maintenance API. The review is bound to the exact source fingerprint, backend fingerprint, and preview ID returned by the Worker. At publish time the Worker rejects a stale preview or changed catalog. Unpublished values exist only in the submitted form and action response; returning to review/edit keeps them for that visit, while a fresh visit starts from the currently published source.

The dashboard Worker enables Cloudflare's `global_fetch_strictly_public` compatibility flag. This is required for its server-side request to reach the API Worker through the public `workers.dev` route in the same Cloudflare zone.

Cloudflare hostname-based applications protect only their specific hostname. The app and global session durations can each be configured up to one month. See [Worker Access](https://developers.cloudflare.com/workers/configuration/cloudflare-access/), [session management](https://developers.cloudflare.com/cloudflare-one/access-controls/access-settings/session-management/), and [Astro's Cloudflare adapter](https://docs.astro.build/en/guides/integrations-guide/cloudflare/).

## Release verification

After Access is configured and the dashboard is deployed, sign in with the founder email and email code in a normal browser. Verify that the catalog page and its server-side source request both work. Confirm that the dashboard has only the protected `workers.dev` hostname, no alternate hostname or custom route, and that preview URLs are disabled. The local signed-token tests are not evidence of this deployed sign-in check. Record its outcome separately from `npm run check`, `npm run build`, and `npm test`.
