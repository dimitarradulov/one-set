import { test } from 'node:test';
import assert from 'node:assert/strict';
import { exportSPKI, generateKeyPair, SignJWT } from 'jose';
import { authenticateClerkRequest } from '../src/authentication.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
};

async function token(claims: Record<string, unknown> = {}) {
  return new SignJWT({ sid: 'session-user', ...claims })
    .setProtectedHeader({ alg: 'RS256' })
    .setSubject('user_123')
    .setIssuer(issuer)
    .setIssuedAt()
    .setNotBefore('0s')
    .setExpirationTime('1m')
    .sign(keys.privateKey);
}

function request(bearer?: string) {
  return new Request('https://api.oneset.test/v1/me/progress', {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}

test('shared Clerk authentication returns a verified account subject', async () => {
  assert.deepEqual(await authenticateClerkRequest(request(await token()), env), { subject: 'user_123' });
});

test('shared Clerk authentication preserves private errors for missing or invalid credentials', async () => {
  const missing = await authenticateClerkRequest(request(), env);
  assert.ok('response' in missing);
  if ('response' in missing) {
    assert.equal(missing.response.status, 401);
    assert.equal(missing.response.headers.get('cache-control'), 'private, no-store');
  }

  const misconfigured = await authenticateClerkRequest(request(await token()), {
    ...env, CLERK_JWT_KEY: '',
  });
  assert.ok('response' in misconfigured);
  if ('response' in misconfigured) assert.equal(misconfigured.response.status, 503);

  const pending = await authenticateClerkRequest(request(await token({ sts: 'pending' })), env);
  assert.ok('response' in pending);
  if ('response' in pending) assert.equal(pending.response.status, 401);
});
