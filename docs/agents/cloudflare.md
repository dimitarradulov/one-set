# Cloudflare CLI workflow

Use terminal commands for all Cloudflare work. Do not use or register Cloudflare MCP servers, including API, documentation, bindings, builds, and observability servers.

## Workers and R2

Use the Wrangler dependency already declared in [worker/package.json](../../worker/package.json). Run commands from `worker/` so Wrangler loads [wrangler.jsonc](../../worker/wrangler.jsonc). If dependencies are missing, install them with `npm ci`; use `npx --no-install wrangler` to avoid downloading a different CLI version.

```sh
cd worker
npx --no-install wrangler --help
npx --no-install wrangler whoami
```

Use `npx --no-install wrangler login` if interactive authentication is needed. For automation, use `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from the environment. Keep credentials out of committed files and command output.

The committed Worker environment is `development`. Select it explicitly for Worker operations:

```sh
npx --no-install wrangler dev --env development
npx --no-install wrangler types --env development
npx --no-install wrangler deployments list --env development
npx --no-install wrangler secret list --env development
npx --no-install wrangler tail --env development
```

When the task calls for deployment or changing a secret:

```sh
npx --no-install wrangler deploy --env development
npx --no-install wrangler secret put SECRET_NAME --env development
```

Use Wrangler's R2 commands for bucket and object operations. Inspect the command's `--help` before use and confirm the intended account, bucket, and object key. Object commands can target local storage; select `--remote` explicitly when working with Cloudflare-hosted objects.

```sh
npx --no-install wrangler r2 bucket list
npx --no-install wrangler r2 object get YOUR_BUCKET/YOUR_OBJECT_KEY --remote --file ./downloaded-object
```

## CDN and other API operations

For CDN cache rules, cache purges, DNS, or other operations unavailable in Wrangler, call the Cloudflare REST API using `curl` from the terminal. Use the official endpoint documentation to confirm the method, payload, and required token permissions. Set `CLOUDFLARE_ZONE_ID` to the intended zone when the endpoint requires it. Wrangler login credentials do not automatically provide a token for `curl`; use `CLOUDFLARE_API_TOKEN` from the environment.

For example, inspect a zone's cache rules with:

```sh
curl --fail-with-body --silent --show-error \
  "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/rulesets/phases/http_request_cache_settings/entrypoint" \
  --header "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
```

Do not enable shell tracing or verbose HTTP logging when credentials are present. Check the API response's `success` field and errors as well as the HTTP status.

Read Cloudflare documentation directly through web browsing or terminal requests. References: [Wrangler commands](https://developers.cloudflare.com/workers/wrangler/commands/), [Cloudflare API](https://developers.cloudflare.com/api/), and [Worker setup](../../worker/README.md).
