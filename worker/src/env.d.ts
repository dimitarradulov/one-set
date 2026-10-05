// Secret bindings are supplied with Wrangler secrets or local .dev.vars.
interface Env {
  DATABASE_URL: string;
  CLERK_JWT_KEY: string;
}
