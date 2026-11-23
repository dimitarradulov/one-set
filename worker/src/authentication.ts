import { verifyToken } from '@clerk/backend';

export interface ClerkConfiguration {
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
}

type AuthenticationResult = { subject: string } | { response: Response };

function errorResponse(code: string, status: number): Response {
  return Response.json({ error: { code } }, {
    status,
    headers: { 'Cache-Control': 'private, no-store' },
  });
}

export async function authenticateClerkRequest(
  request: Request,
  env: ClerkConfiguration,
): Promise<AuthenticationResult> {
  const bearer = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!bearer) return { response: errorResponse('AUTH_REQUIRED', 401) };
  if (!env.CLERK_JWT_KEY || !env.CLERK_ISSUER || !env.CLERK_AUTHORIZED_PARTIES) {
    return { response: errorResponse('TEMPORARY_FAILURE', 503) };
  }

  try {
    const claims = await verifyToken(bearer, { jwtKey: env.CLERK_JWT_KEY, clockSkewInMs: 0 });
    // Native Clerk session tokens may omit azp; browser tokens must match the allowlist.
    const parties = env.CLERK_AUTHORIZED_PARTIES.split(',').map(origin => origin.trim());
    if (claims.iss !== env.CLERK_ISSUER
      || (claims.azp !== undefined && !parties.includes(claims.azp))
      || !claims.sub || !claims.sid || claims.sts === 'pending') {
      return { response: errorResponse('AUTH_REQUIRED', 401) };
    }
    return { subject: claims.sub };
  } catch {
    return { response: errorResponse('AUTH_REQUIRED', 401) };
  }
}
