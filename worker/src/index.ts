import { neon } from '@neondatabase/serverless';
import { handleCatalogRequest } from './catalog';
import { handleCompletedSessionRequest } from './sessions';
import { handleSetupRequest } from './setup';

export default {
  async fetch(request, env): Promise<Response> {
    const path = new URL(request.url).pathname;
    if (path.startsWith('/v1/catalog') || path.startsWith('/v1/maintenance/catalog/')) {
      const sql = neon(env.DATABASE_URL);
      return handleCatalogRequest(request, env, {
        query: async (query, params = []) => sql.query(query, params),
        transaction: async (query, params = []) => {
          const [rows] = await sql.transaction([sql.query(query, params)]);
          return rows;
        },
      });
    }
    const sql = neon(env.DATABASE_URL);
    if (path.startsWith('/v1/sessions/')) {
      return handleCompletedSessionRequest(request, env, {
        query: async (query, params) => sql.query(query, params),
      });
    }
    return handleSetupRequest(request, env, {
      query: async (query, params) => sql.query(query, params),
    });
  },
} satisfies ExportedHandler<Env>;
