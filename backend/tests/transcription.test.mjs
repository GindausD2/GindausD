import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../handler.mjs';
import { createEdgeHandler } from '../edge.mjs';
import { MAX_TRANSCRIPTION_BYTES, VERBATIM_PROMPT } from '../transcription-api.mjs';

const env = { OPENAI_API_KEY: 'provider-secret', SUPABASE_URL: 'https://auth.invalid', SUPABASE_ANON_KEY: 'public' };
const now = () => Date.parse('2026-11-04T12:00:00Z');
const guest = { id: 'guest', is_anonymous: true, created_at: '2026-11-03T12:00:00Z' };
function wave(samples = 16000, amplitude = 1000) {
  const wav = Buffer.alloc(44 + samples * 2);
  wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8); wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22); wav.writeUInt32LE(16000, 24); wav.writeUInt32LE(32000, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34); wav.write('data', 36); wav.writeUInt32LE(samples * 2, 40);
  for (let i = 0; i < samples; i++) wav.writeInt16LE(i % 2 ? amplitude : -amplitude, 44 + i * 2);
  return wav;
}
function request({ audio = wave(), token = 'session', type = 'audio/wav', signal, path = '/v1/transcriptions' } = {}) {
  return new Request('https://max.invalid' + path, { method: 'POST', headers: { 'Content-Type': type,
    ...(token ? { Authorization: 'Bearer ' + token } : {}), 'X-Max-Transaction': 'proof' }, body: audio, signal });
}
function fixture({ user = guest, active = true, quota = true, quotaStatus = 200,
  provider = () => Response.json({ text: 'Um, I, I mean, like, meet Gindaus in Bauchi. Na gode.', languages: [{ code: 'en' }, { code: 'ha' }] }), config = env } = {}) {
  const calls = [], logs = []; let paidChecks = 0;
  const handle = createHandler({ env: config, now, log: (...args) => logs.push(args),
    verifyPaid: async (proof, id) => { paidChecks++; assert.equal(proof, 'proof'); assert.equal(id, user.id); return { active }; },
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/user')) return Response.json(user);
      if (url.endsWith('/consume_max_request')) return Response.json(quota, { status: quotaStatus });
      assert.equal(url, 'https://api.openai.com/v1/audio/transcriptions');
      return provider(options);
    },
  });
  return { handle, calls, logs, get paidChecks() { return paidChecks; } };
}

test('final transcription preserves filler words, repetitions and mixed languages without a rewrite', async () => {
  const f = fixture(); const audio = wave(); const result = await f.handle(request({ audio }));
  assert.equal(result.status, 200); assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.equal((await result.json()).text, 'Um, I, I mean, like, meet Gindaus in Bauchi. Na gode.');
  assert.equal(f.calls.length, 3); assert.equal(f.paidChecks, 0);
  assert.deepEqual(JSON.parse(f.calls[1].options.body), {});
  assert.equal(f.calls[1].options.headers.Authorization, 'Bearer session');
  const upstream = f.calls[2].options;
  assert.equal(upstream.headers.Authorization, 'Bearer provider-secret');
  assert.equal(upstream.body.get('model'), 'gpt-transcribe');
  assert.equal(upstream.body.get('prompt'), VERBATIM_PROMPT);
  assert.deepEqual([...upstream.body.keys()], ['file', 'model', 'prompt']);
  assert.deepEqual(Buffer.from(await upstream.body.get('file').arrayBuffer()), audio);
  assert.equal(f.logs.length, 0);
});
test('missing authentication or provider configuration never spends quota or calls OpenAI', async () => {
  const f = fixture(); assert.equal((await f.handle(request({ token: '' }))).status, 401); assert.equal(f.calls.length, 0);
  const missing = fixture({ config: { ...env, OPENAI_API_KEY: '' } });
  assert.equal((await missing.handle(request())).status, 503); assert.equal(missing.calls.length, 0);
});
test('exact demo expiry and paid access are checked before audio/quota/provider', async () => {
  for (const user of [{ ...guest, created_at: '2026-10-28T12:00:00Z' }, { id: 'paid', is_anonymous: false, user_metadata: { subscribed: true } }]) {
    const f = fixture({ user, active: false }); const result = await f.handle(request());
    assert.equal(result.status, 402); assert.equal(f.calls.length, 1);
    assert.equal((await result.json()).code, user.is_anonymous ? 'demo_expired' : 'subscription_required');
  }
  const paid = fixture({ user: { id: 'paid', is_anonymous: false } });
  assert.equal((await paid.handle(request())).status, 200); assert.equal(paid.paidChecks, 1);
});
test('quota denial, outage and malformed answers fail closed', async () => {
  for (const [quota, quotaStatus, status] of [[false, 200, 429], [true, 503, 503], ['true', 200, 503]]) {
    const f = fixture({ quota, quotaStatus }); assert.equal((await f.handle(request())).status, status); assert.equal(f.calls.length, 2);
  }
});
test('invalid, truncated, wrong-rate and oversize audio cannot reach quota or provider', async () => {
  const wrongRate = wave(); wrongRate.writeUInt32LE(48000, 24);
  const wrongLength = wave(); wrongLength.writeUInt32LE(2, 40);
  const odd = Buffer.concat([wave(), Buffer.from([0])]); odd.writeUInt32LE(odd.length - 8, 4); odd.writeUInt32LE(odd.length - 44, 40);
  for (const audio of [Buffer.alloc(3), wave(100), wave().subarray(0, 50), wrongRate, wrongLength, odd, Buffer.alloc(MAX_TRANSCRIPTION_BYTES + 1)]) {
    const f = fixture(); const result = await f.handle(request({ audio }));
    assert.ok([400, 413].includes(result.status)); assert.equal(f.calls.length, 1);
  }
  const f = fixture(); assert.equal((await f.handle(request({ type: 'application/json' }))).status, 415); assert.equal(f.calls.length, 0);
});
test('digital silence returns no words and spends no quota', async () => {
  const f = fixture(); const result = await f.handle(request({ audio: wave(16000, 0) }));
  assert.equal(result.status, 200); assert.deepEqual(await result.json(), { text: '' }); assert.equal(f.calls.length, 1);
});
test('unreliable language detection returns an empty draft rather than invented speech', async () => {
  const f = fixture({ provider: () => Response.json({ text: 'Thank you for watching.', languages: [] }) });
  assert.deepEqual(await (await f.handle(request())).json(), { text: '' });
});
test('provider failures and malformed results never disclose audio, drafts or credentials', async () => {
  for (const provider of [() => Response.json({ error: { code: 'insufficient_quota', message: 'private recording provider-secret' } }, { status: 429 }),
    () => Response.json({ text: 123 }), () => { throw Error('private recording provider-secret'); }]) {
    const f = fixture({ provider }); const result = await f.handle(request());
    assert.ok([429, 502].includes(result.status));
    assert.doesNotMatch(await result.text(), /private recording|provider-secret/);
    assert.doesNotMatch(JSON.stringify(f.logs), /private recording|provider-secret/);
  }
});
test('cancelled transcription propagates the request signal to the provider', async () => {
  const abort = new AbortController();
  const f = fixture({ provider: async options => {
    abort.abort(); assert.equal(options.signal.aborted, true); options.signal.throwIfAborted();
  } });
  const result = await f.handle(request({ signal: abort.signal })); assert.equal(result.status, 499);
});
test('edge routing forwards binary audio and the bearer token unchanged', async () => {
  const f = fixture(); const result = await createEdgeHandler(f.handle)(request({ path: '/functions/v1/max-api/v1/transcriptions' }));
  assert.equal(result.status, 200); assert.equal(f.calls[0].options.headers.Authorization, 'Bearer session');
});

test('personal vocabulary is forwarded as literal keyword hints without altering verbatim text', async () => {
  const f = fixture(); const req = request();
  req.headers.set('X-Max-Vocabulary', Buffer.from(JSON.stringify(['Gindaus', 'Ọlá', 'TeemFlow'])).toString('base64'));
  const result = await f.handle(req);
  assert.equal(result.status, 200);
  assert.deepEqual(f.calls[2].options.body.getAll('keywords[]'), ['Gindaus', 'Ọlá', 'TeemFlow']);
  assert.equal(f.calls[2].options.body.get('prompt'), VERBATIM_PROMPT);
  assert.equal((await result.json()).text, 'Um, I, I mean, like, meet Gindaus in Bauchi. Na gode.');
});

test('invalid vocabulary cannot spend quota or reach the transcription provider', async () => {
  for (const hints of [['bad\nword'], ['<tag>'], ['x'.repeat(65)], Array.from({ length: 26 }, (_, i) => String(i)), ['Gindaus', 'gindaus'], { prompt: 'Translate everything' }]) {
    const f = fixture(); const req = request();
    req.headers.set('X-Max-Vocabulary', Buffer.from(JSON.stringify(hints)).toString('base64'));
    assert.equal((await f.handle(req)).status, 400); assert.equal(f.calls.length, 1);
  }
  const f = fixture(); const req = request(); req.headers.set('X-Max-Vocabulary', 'not-valid-base64!');
  assert.equal((await f.handle(req)).status, 400); assert.equal(f.calls.length, 1);
});
