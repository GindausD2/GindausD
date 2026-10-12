import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../handler.mjs';
const env = { ANTHROPIC_API_KEY: 'server-secret', SUPABASE_URL: 'https://auth.example', SUPABASE_ANON_KEY: 'public-key' };
const payload = { messages: [{ role: 'user', content: 'Remember my idea' }] };
const request = (body = payload, token = 'valid-session') => new Request('https://max.example/v1/messages', { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: JSON.stringify(body) });
function fixture({ authStatus = 200, quota = true, quotaStatus = 200, providerStatus = 200 } = {}) {
  const calls = [];
  const handler = createHandler({ env, fetchImpl: async (url, options) => {
    calls.push({ url, options });
    if (url.endsWith('/user')) return Response.json({ id: 'verified-user' }, { status: authStatus });
    if (url.includes('/rpc/')) return Response.json(quota, { status: quotaStatus });
    return new Response(providerStatus === 200 ? 'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello ❄️"}}\n\n' : 'server-secret provider error', { status: providerStatus });
  } });
  return { calls, handler };
}
test('missing server configuration fails closed', async () => { const h = createHandler({ env: {}, fetchImpl: () => { throw Error('must not fetch'); } }); assert.equal((await h(request())).status, 503); });
test('missing session never reaches provider', async () => { const f = fixture(); assert.equal((await f.handler(request(payload, ''))).status, 401); assert.equal(f.calls.length, 0); });
test('expired session is rejected before quota or generation', async () => { const f = fixture({ authStatus: 401 }); assert.equal((await f.handler(request())).status, 401); assert.equal(f.calls.length, 1); });
test('booking tools are rejected before generation', async () => { const f = fixture(); assert.equal((await f.handler(request({ ...payload, tools: [{ name: 'book_uber', description: 'Book ride', input_schema: { type: 'object' } }] }))).status, 400); assert.equal(f.calls.length, 0); });
test('quota must be installed and available', async () => { const f = fixture({ quotaStatus: 404 }); assert.equal((await f.handler(request())).status, 503); assert.equal(f.calls.length, 2); });
test('database quota stops exhausted accounts', async () => { const f = fixture({ quota: false }); assert.equal((await f.handler(request())).status, 429); assert.equal(f.calls.length, 2); });
test('verified streaming preserves Unicode and keeps key on server', async () => { const f = fixture(); const r = await f.handler(request({ ...payload, model: 'expensive-client-model', max_tokens: 99999 })); assert.equal(r.status, 200); assert.match(await r.text(), /Hello ❄️/); const last = f.calls.at(-1); assert.equal(last.options.headers['x-api-key'], 'server-secret'); assert.equal(JSON.parse(last.options.body).max_tokens, 2048); assert.equal(JSON.parse(last.options.body).model, 'claude-sonnet-4-6'); assert.equal(f.calls[1].options.headers.Authorization, 'Bearer valid-session'); assert.equal(f.calls[1].options.body, '{}'); });
test('provider errors never disclose credentials', async () => { const f = fixture({ providerStatus: 500 }); const r = await f.handler(request()); assert.equal(r.status, 502); assert.doesNotMatch(await r.text(), /server-secret/); });
test('oversized payloads are rejected before auth', async () => { const f = fixture(); assert.equal((await f.handler(request({ messages: [{ role: 'user', content: 'x'.repeat(270000) }] }))).status, 413); assert.equal(f.calls.length, 0); });
test('null, arrays, and primitive JSON cannot crash the handler', async () => {
  const f = fixture();
  for (const body of [null, [], 'text', 5, true]) assert.equal((await f.handler(request(body))).status, 400);
  assert.equal(f.calls.length, 0);
});
test('malformed quota results fail closed without claiming a limit was exhausted', async () => {
  for (const quota of [null, {}, 'true', 1]) { const f = fixture({ quota }); assert.equal((await f.handler(request())).status, 503); assert.equal(f.calls.length, 2); }
});
test('invalid server URL fails closed before calling auth', async () => {
  for (const SUPABASE_URL of ['https://', 'http://auth.example', 'https://user:password@auth.example', 'https://auth.example?wrong=1']) {
    const h = createHandler({ env: { ...env, SUPABASE_URL }, fetchImpl: () => { throw Error('must not fetch'); } });
    assert.equal((await h(request())).status, 503);
  }
});
test('network exceptions are redacted', async () => {
  const h = createHandler({ env, log: () => {}, fetchImpl: () => { throw Error('server-secret'); } });
  const r = await h(request()); assert.equal(r.status, 502); assert.doesNotMatch(await r.text(), /server-secret/);
});
test('V1 tool continuation blocks reach the provider unchanged', async () => {
  const f = fixture();
  const body = { messages: [payload.messages[0], { role: 'assistant', content: [{ type: 'tool_use', id: 'call-1', name: 'save_note', input: { title: 'Idea', content: 'Glacier ❄️' } }] }, { role: 'user', content: [{ type: 'tool_result', tool_use_id: 'call-1', content: '{"saved":true}' }] }] };
  assert.equal((await f.handler(request(body))).status, 200);
  assert.deepEqual(JSON.parse(f.calls.at(-1).options.body).messages, body.messages);
});
