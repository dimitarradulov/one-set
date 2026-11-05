/// <reference types="astro/client" />

declare module 'cloudflare:workers' {
  export const env: Env;
}

interface Env {
  CATALOG_ENVIRONMENT: string;
  CATALOG_API_BASE_URL: string;
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUDIENCE: string;
  ACCESS_APPROVED_EMAIL: string;
  CATALOG_PUBLISH_TOKEN: string;
}
