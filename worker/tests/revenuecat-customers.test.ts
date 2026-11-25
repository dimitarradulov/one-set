import { test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteCustomer } from '../src/revenuecat-customers.ts';

const config = { REVENUECAT_PROJECT_ID: 'proj_test', REVENUECAT_SECRET_KEY: 'sk_rc_test' };

function stub(status: number | Error) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fetcher = async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    if (status instanceof Error) throw status;
    return new Response('{}', { status });
  };
  return { calls, fetcher: fetcher as typeof fetch };
}

test('deleteCustomer maps RevenueCat responses to typed results', async () => {
  assert.deepEqual(await deleteCustomer('user_1', config, stub(200).fetcher), { status: 'deleted' });
  assert.deepEqual(await deleteCustomer('user_1', config, stub(404).fetcher), { status: 'notFound' });
  assert.deepEqual(await deleteCustomer('user_1', config, stub(500).fetcher), { status: 'temporaryFailure', httpStatus: 500 });
  assert.deepEqual(await deleteCustomer('user_1', config, stub(429).fetcher), { status: 'temporaryFailure', httpStatus: 429 });
  assert.deepEqual(await deleteCustomer('user_1', config, stub(401).fetcher), { status: 'temporaryFailure', httpStatus: 401 });
  assert.deepEqual(await deleteCustomer('user_1', config, stub(new Error('net')).fetcher), { status: 'temporaryFailure' });
});

test('the request deletes the encoded customer in the configured project with the secret key', async () => {
  const s = stub(200);
  await deleteCustomer('user/1', config, s.fetcher);
  assert.equal(s.calls[0].url, 'https://api.revenuecat.com/v2/projects/proj_test/customers/user%2F1');
  assert.equal(s.calls[0].init.method, 'DELETE');
  assert.equal((s.calls[0].init.headers as Record<string, string>).Authorization, 'Bearer sk_rc_test');
  assert.ok(s.calls[0].init.signal instanceof AbortSignal);
});

test('missing configuration is a temporary failure without calling RevenueCat', async () => {
  const s = stub(200);
  assert.deepEqual(
    await deleteCustomer('user_1', { ...config, REVENUECAT_SECRET_KEY: '' }, s.fetcher),
    { status: 'temporaryFailure' },
  );
  assert.deepEqual(
    await deleteCustomer('user_1', { ...config, REVENUECAT_PROJECT_ID: '' }, s.fetcher),
    { status: 'temporaryFailure' },
  );
  assert.equal(s.calls.length, 0);
});
