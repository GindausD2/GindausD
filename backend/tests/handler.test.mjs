import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../handler.mjs';
import { textStream, frame, chunk } from './openai-fixtures.mjs';
const env = { OPENAI_API_KEY: 'server-secret', SUPABASE_URL: 'https://auth.example', SUPABASE_ANON_KEY: 'public-key' };
const payload = { messages: [{ role: 'user', content: 'Remember my idea' }] };
const request = (body = payload, token = 'valid-session') => new Request('https://max.example/v1/messages', { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: JSON.stringify(body) });
function fixture({ authStatus = 200, quota = true, quotaStatus = 200, providerStatus = 200, user = { id: 'verified-user' }, now = Date.now } = {}) {
  const calls = [];
  const handler = createHandler({ env, now, fetchImpl: async (url, options) => {
    calls.push({ url, options });
    if (url.endsWith('/user')) return Response.json(user, { status: authStatus });
    if (url.includes('/rpc/')) return Response.json(quota, { status: quotaStatus });
    return new Response(providerStatus === 200 ? textStream('Hello ❄️') : 'server-secret provider error', { status: providerStatus });
  } });
  return { calls, handler };
}
test('missing server configuration fails closed', async () => { const h = createHandler({ env: {}, fetchImpl: () => { throw Error('must not fetch'); } }); assert.equal((await h(request())).status, 503); });
test('an old Anthropic key cannot silently configure the OpenAI backend', async () => {
  const h = createHandler({ env: { SUPABASE_URL: env.SUPABASE_URL, SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY, ANTHROPIC_API_KEY: 'legacy-secret' }, fetchImpl: () => { throw Error('must not fetch'); } });
  assert.equal((await h(request())).status, 503);
});
test('missing session never reaches provider', async () => { const f = fixture(); assert.equal((await f.handler(request(payload, ''))).status, 401); assert.equal(f.calls.length, 0); });
test('expired session is rejected before quota or generation', async () => { const f = fixture({ authStatus: 401 }); assert.equal((await f.handler(request())).status, 401); assert.equal(f.calls.length, 1); });
test('booking tools are rejected before generation', async () => { const f = fixture(); assert.equal((await f.handler(request({ ...payload, tools: [{ name: 'book_uber', description: 'Book ride', input_schema: { type: 'object' } }] }))).status, 400); assert.equal(f.calls.length, 0); });
test('quota must be installed and available', async () => { const f = fixture({ quotaStatus: 404 }); assert.equal((await f.handler(request())).status, 503); assert.equal(f.calls.length, 2); });
test('database quota stops exhausted accounts', async () => { const f = fixture({ quota: false }); assert.equal((await f.handler(request())).status, 429); assert.equal(f.calls.length, 2); });
test('verified streaming preserves Unicode and keeps key on server', async () => { const f = fixture(); const r = await f.handler(request({ ...payload, model: 'expensive-client-model', max_tokens: 99999 })); assert.equal(r.status, 200); assert.match(await r.text(), /Hello ❄️/); const last = f.calls.at(-1); assert.equal(last.options.headers.Authorization, 'Bearer server-secret'); assert.equal(JSON.parse(last.options.body).max_completion_tokens, 2048); assert.equal(JSON.parse(last.options.body).model, 'gpt-5.4-mini'); assert.equal(f.calls[1].options.headers.Authorization, 'Bearer valid-session'); assert.equal(f.calls[1].options.body, '{}'); });
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
test('V1 tool continuation is translated to OpenAI function messages', async () => {
  const f = fixture();
  const body = { messages: [payload.messages[0], { role: 'assistant', content: [{ type: 'tool_use', id: 'call-1', name: 'save_note', input: { title: 'Idea', content: 'Glacier ❄️' } }] }, { role: 'user', content: [{ type: 'tool_result', tool_use_id: 'call-1', content: '{"saved":true}' }] }] };
  assert.equal((await f.handler(request(body))).status, 200);
  const messages = JSON.parse(f.calls.at(-1).options.body).messages;
  assert.equal(messages[0].role, 'developer');
  assert.equal(messages[2].tool_calls[0].function.name, 'save_note');
  assert.deepEqual(JSON.parse(messages[2].tool_calls[0].function.arguments), { title: 'Idea', content: 'Glacier ❄️' });
  assert.deepEqual(messages[3], { role: 'tool', tool_call_id: 'call-1', content: '{\"saved\":true}' });
});
test('full native tool feedback round trip retains IDs, schema and per-request quotas', async () => {
  let generations = 0, quotas = 0;
  const h = createHandler({ env, fetchImpl: async (url, options) => {
    if (url.endsWith('/user')) return Response.json({ id: 'verified-user' });
    if (url.includes('/rpc/')) { quotas++; return Response.json(true); }
    assert.equal(url, 'https://api.openai.com/v1/chat/completions');
    const body = JSON.parse(options.body);
    assert.equal(body.store, false); assert.equal(body.parallel_tool_calls, false);
    assert.deepEqual(body.tools[0].function.parameters, { type: 'object', properties: {} });
    generations++;
    if (generations === 1) return new Response(frame(chunk({ tool_calls: [{ index: 0, id: 'call-1', type: 'function', function: { name: 'get_datetime', arguments: '{}' } }] })) + frame(chunk({}, 'tool_calls')) + frame('[DONE]'));
    assert.deepEqual(body.messages.at(-1), { role: 'tool', tool_call_id: 'call-1', content: '2026-10-14T12:00:00+01:00' });
    return new Response(textStream('It is noon.'));
  } });
  const tools = [{ name: 'get_datetime', description: 'Current time', input_schema: { type: 'object', properties: {} } }];
  const first = await h(request({ messages: [{ role: 'user', content: 'What time is it?' }], tools }));
  assert.match(await first.text(), /"stop_reason":"tool_use"/);
  const second = await h(request({ messages: [{ role: 'user', content: 'What time is it?' }, { role: 'assistant', content: [{ type: 'tool_use', id: 'call-1', name: 'get_datetime', input: {} }] }, { role: 'user', content: [{ type: 'tool_result', tool_use_id: 'call-1', content: '2026-10-14T12:00:00+01:00' }] }], tools }));
  assert.match(await second.text(), /It is noon/); assert.equal(generations, 2); assert.equal(quotas, 2);
});

const trialStart = Date.parse('2026-10-01T08:00:00.000Z');
const trialEnd = trialStart + 7 * 24 * 60 * 60 * 1000;
const guest = { id: 'guest-account', is_anonymous: true, created_at: new Date(trialStart).toISOString() };
test('a guest can stream real AI before seven days without an Apple identity', async () => {
  const f = fixture({ user: guest, now: () => trialEnd - 1 });
  const response = await f.handler(request());
  assert.equal(response.status, 200);
  assert.match(await response.text(), /Hello/);
  assert.equal(f.calls.length, 3);
});
test('guest expiry is exact and refresh/client trial claims cannot restart it', async () => {
  for (const current of [trialEnd, trialEnd + 86400000]) {
    const f = fixture({ user: { ...guest, last_sign_in_at: new Date(current).toISOString(), user_metadata: { is_anonymous: false, trial_started_at: new Date(current).toISOString() } }, now: () => current });
    const response = await f.handler(request({ ...payload, is_anonymous: false, trial_started_at: new Date(current).toISOString() }));
    assert.equal(response.status, 402);
    assert.equal((await response.json()).code, 'demo_expired');
    assert.equal(f.calls.length, 1, 'expired guests must not consume quota or reach OpenAI');
  }
});
test('missing, invalid and future guest timestamps fail closed', async () => {
  for (const created_at of [undefined, null, '', 'invalid', trialStart, new Date(trialEnd + 1).toISOString()]) {
    const f = fixture({ user: { ...guest, created_at }, now: () => trialEnd });
    assert.equal((await f.handler(request())).status, 503);
    assert.equal(f.calls.length, 1);
  }
  const f = fixture({ user: { ...guest, is_anonymous: 'false' } });
  assert.equal((await f.handler(request())).status, 503);
  assert.equal(f.calls.length, 1);
});
test('a verified permanent user is not mistaken for an expired guest', async () => {
  const f = fixture({ user: { ...guest, is_anonymous: false }, now: () => trialEnd });
  assert.equal((await f.handler(request())).status, 200);
});
