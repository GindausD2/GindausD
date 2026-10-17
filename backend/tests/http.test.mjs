import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createMaxServer } from '../server.mjs';
import { createHandler } from '../handler.mjs';
import { frame, chunk, textStream } from './openai-fixtures.mjs';

const env = { OPENAI_API_KEY: 'http-test-secret', SUPABASE_URL: 'https://auth.example', SUPABASE_ANON_KEY: 'public-key' };
const body = JSON.stringify({ messages: [{ role: 'user', content: 'Hello' }] });
async function serve(t, handle) {
  const server = createMaxServer({ handle }); server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = 'http://127.0.0.1:' + server.address().port;
  return { base, post: (data = body, extra = {}) => fetch(base + '/v1/messages', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer test-session' }, body: data, ...extra }) };
}
test('actual HTTP adapter serves health and returns validation errors', async t => {
  let calls = 0;
  const { base, post } = await serve(t, createHandler({ env, fetchImpl: () => { calls++; throw Error('not expected'); } }));
  assert.equal((await fetch(base + '/health')).status, 200);
  assert.equal((await post('null')).status, 400);
  assert.equal((await post('{')).status, 400);
  assert.equal((await post('x'.repeat(270000))).status, 413);
  assert.equal((await fetch(base + '/v1/messages')).status, 405);
  assert.equal((await fetch(base + '/missing')).status, 404);
  assert.equal(calls, 0);
});
test('actual HTTP streaming preserves split Unicode bytes and server key isolation', async t => {
  const calls = [];
  const expected = textStream('Hello ❄️ — café');
  const handle = createHandler({ env, fetchImpl: async (url, options) => {
    calls.push({ url, options });
    if (url.endsWith('/user')) return Response.json({ id: 'http-user' });
    if (url.includes('/rpc/')) return Response.json(true);
    const bytes = new TextEncoder().encode(expected);
    return new Response(new ReadableStream({ start(controller) { for (const byte of bytes) controller.enqueue(Uint8Array.of(byte)); controller.close(); } }));
  } });
  const { post } = await serve(t, handle);
  const response = await post();
  assert.equal(response.status, 200); assert.match(response.headers.get('content-type'), /text\/event-stream/);
  const output = await response.text();
  assert.match(output, /Hello ❄️ — café/); assert.match(output, /message_stop/);
  assert.equal(calls.at(-1).options.headers.Authorization, 'Bearer ' + env.OPENAI_API_KEY);
  assert.doesNotMatch(expected, /http-test-secret/);
});
test('HTTP client disconnect cancels the upstream stream', async t => {
  let cancelled;
  const cancellation = new Promise(resolve => { cancelled = resolve; });
  const handle = createHandler({ env, fetchImpl: async (url, options) => {
    if (url.endsWith('/user')) return Response.json({ id: 'http-user' });
    if (url.includes('/rpc/')) return Response.json(true);
    return new Response(new ReadableStream({
      start(controller) {
        controller.enqueue(new TextEncoder().encode(frame(chunk({ content: 'starting' }))));
        options.signal.addEventListener('abort', () => { controller.error(options.signal.reason); cancelled(); }, { once: true });
      }
    }));
  } });
  const { post } = await serve(t, handle);
  const controller = new AbortController();
  const response = await post(body, { signal: controller.signal });
  await response.body.getReader().read(); controller.abort();
  await Promise.race([cancellation, new Promise((_, reject) => { const timer = setTimeout(() => reject(Error('upstream was not cancelled')), 2000); timer.unref(); })]);
});
