// Secret bindings are supplied with Wrangler secrets or local .dev.vars.
interface Env {
  DATABASE_URL: string;
  CLERK_JWT_KEY: string;
  CATALOG_PUBLISH_TOKEN: string;
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUDIENCE: string;
  ACCESS_APPROVED_EMAIL: string;
}
