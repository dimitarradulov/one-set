import { test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteUser, getUser } from '../src/clerk-users.ts';

function stub(status: number | Error) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fetcher = async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    if (status instanceof Error) throw status;
    return new Response('{}', { status });
  };
  return { calls, fetcher: fetcher as typeof fetch };
}

test('deleteUser maps Clerk responses to typed results', async () => {
  assert.deepEqual(await deleteUser('user_1', 'sk_test', stub(200).fetcher), { status: 'success' });
  assert.deepEqual(await deleteUser('user_1', 'sk_test', stub(404).fetcher), { status: 'notFound' });
  assert.deepEqual(await deleteUser('user_1', 'sk_test', stub(500).fetcher), { status: 'temporaryFailure' });
  assert.deepEqual(await deleteUser('user_1', 'sk_test', stub(429).fetcher), { status: 'temporaryFailure' });
  assert.deepEqual(await deleteUser('user_1', 'sk_test', stub(new Error('net')).fetcher), { status: 'temporaryFailure' });
});

test('getUser maps Clerk responses to typed results', async () => {
  assert.deepEqual(await getUser('user_1', 'sk_test', stub(200).fetcher), { status: 'success' });
  assert.deepEqual(await getUser('user_1', 'sk_test', stub(404).fetcher), { status: 'notFound' });
  assert.deepEqual(await getUser('user_1', 'sk_test', stub(503).fetcher), { status: 'temporaryFailure' });
});

test('requests use the secret as a bearer token and encode the user id', async () => {
  const del = stub(200);
  await deleteUser('user/1', 'sk_test', del.fetcher);
  assert.equal(del.calls[0].url, 'https://api.clerk.com/v1/users/user%2F1');
  assert.equal(del.calls[0].init.method, 'DELETE');
  assert.equal((del.calls[0].init.headers as Record<string, string>).Authorization, 'Bearer sk_test');
  const get = stub(200);
  await getUser('user_1', 'sk_test', get.fetcher);
  assert.equal(get.calls[0].init.method, 'GET');
});

test('a missing secret is a temporary failure without calling Clerk', async () => {
  const s = stub(200);
  assert.deepEqual(await deleteUser('user_1', '', s.fetcher), { status: 'temporaryFailure' });
  assert.equal(s.calls.length, 0);
});
