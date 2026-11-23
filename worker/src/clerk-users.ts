const CLERK_API = 'https://api.clerk.com/v1/users';
const REQUEST_TIMEOUT_MS = 5000;

export type ClerkUserResult =
  | { status: 'success' }
  | { status: 'notFound' }
  | { status: 'temporaryFailure' };

async function request(
  method: 'GET' | 'DELETE',
  userId: string,
  secretKey: string,
  fetcher: typeof fetch,
): Promise<ClerkUserResult> {
  if (!secretKey) return { status: 'temporaryFailure' };
  try {
    const response = await fetcher(`${CLERK_API}/${encodeURIComponent(userId)}`, {
      method,
      headers: { Authorization: `Bearer ${secretKey}` },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    // Release the connection; the body is not needed.
    await response.body?.cancel();
    if (response.ok) return { status: 'success' };
    if (response.status === 404) return { status: 'notFound' };
    return { status: 'temporaryFailure' };
  } catch {
    return { status: 'temporaryFailure' };
  }
}

export function deleteUser(userId: string, secretKey: string, fetcher: typeof fetch = fetch) {
  return request('DELETE', userId, secretKey, fetcher);
}

export function getUser(userId: string, secretKey: string, fetcher: typeof fetch = fetch) {
  return request('GET', userId, secretKey, fetcher);
}
