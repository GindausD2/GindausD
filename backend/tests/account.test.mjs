import test from 'node:test';
import assert from 'node:assert/strict';
import { createAccountAPI } from '../account-api.mjs';

const id = '56c05262-507d-4a33-bcf9-5c8370d6df82';
const env = {
  SUPABASE_URL: 'https://auth.example', SUPABASE_ANON_KEY: 'public-key',
  SUPABASE_SERVICE_ROLE_KEY: 'server-key', MAX_APPLE_SIGN_IN_CLIENT_ID: 'com.gindausd.max',
  MAX_APPLE_SIGN_IN_CLIENT_SECRET: 'apple-secret',
};
const request = (body, bearer = 'current-session') => new Request('https://max.example/v1/account/delete', {
  method: 'POST',
  headers: { Authorization: 'Bearer ' + bearer, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});
const identity = { id, is_anonymous: false, identities: [{ provider: 'apple', identity_data: { sub: 'apple-user' } }] };
const appleToken = sub => 'header.' + Buffer.from(JSON.stringify({
  iss: 'https://appleid.apple.com', aud: 'com.gindausd.max', sub,
})).toString('base64url') + '.signature';

test('revokes the matching Apple identity before deleting the authenticated account', async () => {
  const calls = [];
  const handler = createAccountAPI({ env, fetchImpl: async (url, options) => {
    calls.push(url);
    if (url.endsWith('/auth/v1/user')) {
      assert.equal(options.headers.Authorization, 'Bearer current-session');
      return Response.json(identity);
    }
    if (url.endsWith('/token')) {
      assert.equal(options.body.get('code'), 'fresh-code');
      return Response.json({ id_token: appleToken('apple-user'), refresh_token: 'apple-refresh' });
    }
    if (url.endsWith('/revoke')) {
      assert.equal(options.body.get('token'), 'apple-refresh');
      return new Response(null, { status: 200 });
    }
    assert.equal(url, 'https://auth.example/auth/v1/admin/users/' + id);
    assert.equal(options.method, 'DELETE');
    assert.equal(options.headers.Authorization, 'Bearer server-key');
    return new Response(null, { status: 200 });
  } });
  const response = await handler(request({ appleCode: 'fresh-code', userId: 'ignored-id' }));
  assert.equal(response.status, 204);
  assert.deepEqual(calls.map(url => new URL(url).pathname), ['/auth/v1/user', '/auth/token', '/auth/revoke', '/auth/v1/admin/users/' + id]);
});

test('rejects a different Apple identity and makes no destructive request', async () => {
  const handler = createAccountAPI({ env, fetchImpl: async url => {
    if (url.endsWith('/auth/v1/user')) return Response.json(identity);
    if (url.endsWith('/token')) return Response.json({ id_token: appleToken('other-user'), refresh_token: 'other-refresh' });
    assert.fail('Unexpected destructive request');
  } });
  assert.equal((await handler(request({ appleCode: 'code' }))).status, 403);
});

test('rejects an expired session without touching Apple or admin APIs', async () => {
  const handler = createAccountAPI({ env, fetchImpl: async url => {
    assert.equal(url, 'https://auth.example/auth/v1/user');
    return new Response(null, { status: 401 });
  } });
  assert.equal((await handler(request({ appleCode: 'code' }))).status, 401);
});

test('a verified guest can delete without Apple credentials or an active subscription', async () => {
  const handler = createAccountAPI({ env: { ...env, MAX_APPLE_SIGN_IN_CLIENT_SECRET: '' }, fetchImpl: async url => {
    if (url.endsWith('/auth/v1/user')) return Response.json({ id, is_anonymous: true });
    assert.equal(url, 'https://auth.example/auth/v1/admin/users/' + id);
    return new Response(null, { status: 200 });
  } });
  assert.equal((await handler(request({}))).status, 204);
});
