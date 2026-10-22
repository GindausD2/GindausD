import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../handler.mjs';
import { createEdgeHandler } from '../edge.mjs';
import { textStream } from './openai-fixtures.mjs';

test('edge routing preserves request body and verified bearer token before OpenAI', async () => {
  for (const prefix of ['/max-api', '/functions/v1/max-api']) {
    const calls = [];
    const handler = createEdgeHandler(createHandler({ verifyPaid: async () => ({ active: true }), env: { OPENAI_API_KEY: 'secret', SUPABASE_URL: 'https://auth.example', SUPABASE_ANON_KEY: 'public' }, fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/user')) return Response.json({ id: 'verified', is_anonymous: false });
      if (url.includes('/rpc/')) return Response.json(true);
      return new Response(textStream('Hello'));
    } }));
    const response = await handler(new Request('https://max.example' + prefix + '/v1/messages', { method: 'POST', headers: { Authorization: 'Bearer session', 'Content-Type': 'application/json' }, body: JSON.stringify({ messages: [{ role: 'user', content: 'Hello' }] }) }));
    assert.equal(response.status, 200); assert.match(await response.text(), /message_stop/);
    assert.equal(calls[0].options.headers.Authorization, 'Bearer session');
    assert.equal(JSON.parse(calls[2].options.body).messages[1].content, 'Hello');
  }
});
test('edge health reports missing provider configuration without exposing secrets', async () => {
  const handler = createEdgeHandler(createHandler({ env: {}, fetchImpl: () => { throw Error('not expected'); } }));
  const response = await handler(new Request('https://max.example/functions/v1/max-api/health'));
  assert.deepEqual(await response.json(), { service: 'max', status: 'running', provider: 'openai', aiConfigured: false, authConfigured: false });
  assert.equal((await handler(new Request('https://max.example/max-api-wrong/health'))).status, 404);
});
test('edge conversation without a session cannot call auth, quota or provider', async () => {
  const handler = createEdgeHandler(createHandler({ verifyPaid: async () => ({ active: true }), env: { OPENAI_API_KEY: 'secret', SUPABASE_URL: 'https://auth.example', SUPABASE_ANON_KEY: 'public' }, fetchImpl: () => { throw Error('must not fetch'); } }));
  const response = await handler(new Request('https://max.example/max-api/v1/messages', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }));
  assert.equal(response.status, 401);
});
