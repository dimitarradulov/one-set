import { authenticateClerkRequest, type ClerkConfiguration } from './authentication';
import { deleteUser, type ClerkUserResult } from './clerk-users';

export interface AccountErasureStatement {
  query: string;
  params: string[];
}

// Runs every statement in one Postgres transaction: all succeed or none apply.
export interface AccountErasureDatabase {
  transaction(statements: AccountErasureStatement[]): Promise<unknown>;
}

export interface AccountDeletionConfiguration extends ClerkConfiguration {
  CLERK_SECRET_KEY: string;
}

export interface AccountDeletionServices {
  cleanupSubscription(clerkUserId: string): Promise<void>;
  deleteClerkUser(clerkUserId: string, secretKey: string): Promise<ClerkUserResult>;
  log(entry: Record<string, string>): void;
}

const OWNED_USER = '(SELECT id FROM users WHERE clerk_user_id = $1)';
const OWNED_PROGRAMS = `(SELECT id FROM user_programs WHERE user_id = ${OWNED_USER})`;

// Children first, then programs, then the user. Unlinking the active cycle lets
// user_programs be deleted before users despite the circular foreign key.
const ERASURE_QUERIES = [
  `UPDATE users SET active_user_program_id = NULL WHERE clerk_user_id = $1`,
  `DELETE FROM workout_session_sets WHERE workout_session_id IN
     (SELECT id FROM workout_sessions WHERE user_program_id IN ${OWNED_PROGRAMS})`,
  `DELETE FROM workout_sessions WHERE user_program_id IN ${OWNED_PROGRAMS}`,
  `DELETE FROM completed_workouts WHERE user_program_id IN ${OWNED_PROGRAMS}`,
  `DELETE FROM user_workout_exercises WHERE user_program_id IN ${OWNED_PROGRAMS}`,
  `DELETE FROM user_program_workout_periods WHERE user_program_id IN ${OWNED_PROGRAMS}`,
  `DELETE FROM user_programs WHERE user_id = ${OWNED_USER}`,
  `DELETE FROM users WHERE clerk_user_id = $1`,
];

// Deletes every row owned by the Clerk user in one transaction. Idempotent: it
// succeeds without changes when the user has no rows. Also used by the stale-token guard.
export async function eraseAccountData(database: AccountErasureDatabase, clerkUserId: string): Promise<void> {
  await database.transaction(ERASURE_QUERIES.map(query => ({ query, params: [clerkUserId] })));
}

// Placeholder until subscription cleanup (RevenueCat) is added. Must stay idempotent.
export async function cleanupSubscription(_clerkUserId: string): Promise<void> {}

const defaultServices: AccountDeletionServices = {
  cleanupSubscription,
  deleteClerkUser: (clerkUserId, secretKey) => deleteUser(clerkUserId, secretKey),
  log: entry => console.error(JSON.stringify(entry)),
};

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}

const temporaryFailure = () => json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);

export async function handleAccountDeletionRequest(
  request: Request,
  env: AccountDeletionConfiguration,
  database: AccountErasureDatabase,
  services: AccountDeletionServices = defaultServices,
): Promise<Response> {
  if (new URL(request.url).pathname !== '/v1/me') return json({ error: { code: 'NOT_FOUND' } }, 404);
  if (request.method !== 'DELETE') return json({ error: { code: 'METHOD_NOT_ALLOWED' } }, 405);

  const authentication = await authenticateClerkRequest(request, env);
  if ('response' in authentication) return authentication.response;
  if (!env.CLERK_SECRET_KEY) return temporaryFailure();
  const clerkUserId = authentication.subject;

  // Every step is idempotent, so a failed attempt is finished by the next call.
  try {
    await eraseAccountData(database, clerkUserId);
    await services.cleanupSubscription(clerkUserId);
    const identity = await services.deleteClerkUser(clerkUserId, env.CLERK_SECRET_KEY);
    if (identity.status === 'temporaryFailure') return temporaryFailure();
  } catch {
    return temporaryFailure();
  }

  // Remove rows a stale token's setup request may have inserted during the race.
  // The identity is gone and the client cannot retry, so a failure is logged for an operator.
  try {
    await eraseAccountData(database, clerkUserId);
  } catch {
    services.log({ event: 'account_deletion_sweep_failed', clerk_user_id: clerkUserId });
  }
  return json({ status: 'deleted' });
}
