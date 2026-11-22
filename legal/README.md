# OneSet legal pages

Static pages served by the `oneset-legal` Worker using Cloudflare static assets. There is no Worker script; Wrangler uploads `public/` as-is.

| Page | URL |
| --- | --- |
| Privacy Policy | https://oneset-legal.dimitarradulovv.workers.dev/privacy |

The RevenueCat paywall and the App Store Connect Privacy Policy URL point to this page. Terms use Apple's [standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/).

Deploy from this directory with the API Worker's Wrangler installation:

```sh
../worker/node_modules/.bin/wrangler deploy
```

Update the effective date in `public/privacy.html` whenever the policy changes. When a custom domain is bought, add it as a Worker custom domain and update the RevenueCat and App Store Connect links.
