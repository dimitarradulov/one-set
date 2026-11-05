# Private catalog dashboard

The dashboard in this directory is a server-rendered Astro site for laptop browsing of the complete published catalog. It uses the existing API and Neon publication record. It has no editor, draft storage, or client application framework. It is deployed to `https://oneset-catalog-dashboard.dimitarradulovv.workers.dev` behind a hostname-specific Cloudflare Access application. Preview URLs and custom domain routes are disabled.

## Local development and checks

Use Node 22 or later:

```sh
npm ci
npm run dev
npm run check
npm run build
npm test
```

The Worker request integration runs with signed test tokens and a controlled key source, then calls the real maintenance source-read handler over HTTP. It covers removed catalog records, the publication identity, denied identities, and storage failure. These local checks simulate Access token verification. They do not perform a Cloudflare login or verify a deployed Access application.

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

The API still needs its existing `DATABASE_URL`, `CLERK_JWT_KEY`, and `CATALOG_PUBLISH_TOKEN` secrets. The dashboard reads only the configured `CATALOG_API_BASE_URL` and `CATALOG_ENVIRONMENT`; both values are server-side Worker variables. The deployment must point to the intended API explicitly. If the database cannot be read, the page returns an unavailable response rather than rendering an empty catalog.

The dashboard Worker enables Cloudflare's `global_fetch_strictly_public` compatibility flag. This is required for its server-side request to reach the API Worker through the public `workers.dev` route in the same Cloudflare zone.

Cloudflare hostname-based applications protect only their specific hostname. The app and global session durations can each be configured up to one month. See [Worker Access](https://developers.cloudflare.com/workers/configuration/cloudflare-access/), [session management](https://developers.cloudflare.com/cloudflare-one/access-controls/access-settings/session-management/), and [Astro's Cloudflare adapter](https://docs.astro.build/en/guides/integrations-guide/cloudflare/).

## Release verification

After Access is configured and the dashboard is deployed, sign in with the founder email and email code in a normal browser. Verify that the catalog page and its server-side source request both work. Confirm that the dashboard has only the protected `workers.dev` hostname, no alternate hostname or custom route, and that preview URLs are disabled. The local signed-token tests are not evidence of this deployed sign-in check. Record its outcome separately from `npm run check`, `npm run build`, and `npm test`.
