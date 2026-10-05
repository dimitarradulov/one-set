import { neon } from '@neondatabase/serverless';
import { handleSetupRequest } from './setup';

export default {
  async fetch(request, env): Promise<Response> {
    return handleSetupRequest(request, env, {
      query: async (query, params) => {
        const sql = neon(env.DATABASE_URL);
        return sql.query(query, params);
      },
    });
  },
} satisfies ExportedHandler<Env>;
