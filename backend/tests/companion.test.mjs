import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { createHandler } from '../handler.mjs';
import { createAppleSubscriptionVerifier, SubscriptionUnavailable } from '../apple-subscriptions.mjs';
import { realtimeSpeech, pcmWave } from '../realtime-speech.mjs';

const account = '11111111-1111-4111-8111-111111111111';
const env = { OPENAI_API_KEY: 'secret', SUPABASE_URL: 'https://auth.example', SUPABASE_ANON_KEY: 'public' };
const now = () => Date.parse('2026-10-21T12:00:00Z');
const guest = { id: account, is_anonymous: true, created_at: '2026-10-20T12:00:00Z' };
const permanent = { id: account, is_anonymous: false };
function request(path = '/v1/speech', body = { text: 'Hello.', voice: 'marin' }, token = 'session', proof = 'signed-proof') {
  return new Request('https://max.example' + path, { method: 'POST', headers: {
    'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}), 'X-Max-Transaction': proof,
  }, body: JSON.stringify(body) });
}
function fixture({ user = guest, active = true, quota = true, quotaStatus = 200 } = {}) {
  const calls = []; let paidChecks = 0, voices = 0;
  const handler = createHandler({ env, now,
    verifyPaid: async (proof, id) => { paidChecks++; assert.equal(id, account); return active && proof === 'signed-proof' ? { active: true, productID: 'com.gindausd.max.pro.monthly', expiresAt: '2026-11-21T00:00:00.000Z' } : null; },
    speak: async ({ text, voice }) => { voices++; assert.equal(voice, 'marin'); assert.equal(text, 'Hello.'); return pcmWave(Buffer.alloc(100)); },
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/user')) return Response.json(user);
      if (url.endsWith('/consume_max_voice')) return Response.json(quota, { status: quotaStatus });
      throw Error('Unexpected generation');
    },
  });
  return { handler, calls, get paidChecks() { return paidChecks; }, get voices() { return voices; } };
}
test('voice requires verified auth and does not expose the provider key', async () => {
  const f = fixture(); assert.equal((await f.handler(request(undefined, undefined, ''))).status, 401);
  assert.equal(f.calls.length, 0); assert.equal(f.voices, 0);
  const r = await f.handler(request()); assert.equal(r.status, 200); assert.equal(r.headers.get('content-type'), 'audio/wav');
  assert.equal(r.headers.get('cache-control'), 'no-store'); assert.equal((await r.arrayBuffer()).byteLength, 144);
  assert.equal(f.paidChecks, 0); assert.deepEqual(JSON.parse(f.calls[1].options.body), { characters: 6 });
  assert.equal(f.calls[1].options.headers.Authorization, 'Bearer session');
});
test('expired guests and malformed verified users cannot spend voice credits', async () => {
  for (const user of [{ ...guest, created_at: '2026-10-14T12:00:00Z' }, { id: account }, { ...guest, created_at: '2027-01-01' }]) {
    const f = fixture({ user }); const r = await f.handler(request());
    assert.ok([402, 503].includes(r.status)); assert.equal(f.calls.length, 1); assert.equal(f.voices, 0);
  }
});
test('permanent users need server-verified subscriptions for speech and text', async () => {
  for (const path of ['/v1/speech', '/v1/messages']) {
    const f = fixture({ user: { ...permanent, user_metadata: { subscribed: true } }, active: false });
    const body = path.endsWith('speech') ? { text: 'Hello.', voice: 'marin', subscribed: true } : { messages: [{ role: 'user', content: 'Hello' }], subscribed: true };
    const r = await f.handler(request(path, body)); assert.equal(r.status, 402);
    assert.equal((await r.json()).code, 'subscription_required'); assert.equal(f.calls.length, 1); assert.equal(f.voices, 0);
  }
});
test('verified paid account receives bounded voice; subscription endpoint uses the body proof', async () => {
  const f = fixture({ user: permanent }); assert.equal((await f.handler(request())).status, 200);
  assert.equal(f.paidChecks, 1);
  const r = await f.handler(request('/v1/subscription', { signedTransaction: 'signed-proof' }));
  assert.equal(r.status, 200); assert.equal((await r.json()).active, true);
  assert.equal((await f.handler(request('/v1/subscription', {}))).status, 402);
});
test('unsupported voices, empty or excessive text fail before auth', async () => {
  const f = fixture();
  for (const body of [{ text: '', voice: 'marin' }, { text: 'x'.repeat(1001), voice: 'marin' }, { text: 'Hello', voice: 'arbitrary' }]) {
    assert.equal((await f.handler(request('/v1/speech', body))).status, 400);
  }
  assert.equal(f.calls.length, 0);
});
test('voice quota failures and malformed responses never reach OpenAI', async () => {
  for (const [quota, quotaStatus, status] of [[false, 200, 429], [true, 404, 503], ['true', 200, 503]]) {
    const f = fixture({ quota, quotaStatus }); const r = await f.handler(request());
    assert.equal(r.status, status); assert.equal(f.voices, 0);
  }
});

const appleEnv = { APPLE_IAP_KEY_ID: 'key', APPLE_IAP_ISSUER_ID: 'issuer', APPLE_IAP_PRIVATE_KEY: 'private', APPLE_APP_ID: '123456', APPLE_ROOT_CERTIFICATES_BASE64: '["Y2VydA=="]' };
function appleFixture({ owner = account, revoked, status = 1, product = 'com.gindausd.max.pro.monthly', expired = false, serverFailure = false, forged = false } = {}) {
  const tx = { appAccountToken: owner, bundleId: 'com.gindausd.max', productId: product, type: 'Auto-Renewable Subscription', originalTransactionId: 'original', expiresDate: now() + (expired ? -1 : 100000), revocationDate: revoked };
  let requests = 0;
  const verify = createAppleSubscriptionVerifier({ env: appleEnv, now, loadLibrary: async () => ({
    SignedDataVerifier: class { async verifyAndDecodeTransaction(value) { if (forged) throw Error(); return value === 'current' ? { ...tx, revocationDate: revoked } : { ...tx, revocationDate: undefined }; } },
    AppStoreServerAPIClient: class { async getAllSubscriptionStatuses(id) { requests++; assert.equal(id, 'original'); if (serverFailure) throw Error(); return { data: [{ lastTransactions: [{ status, signedTransactionInfo: 'current' }] }] }; } },
  }) });
  return { verify, get requests() { return requests; } };
}
test('subscription verifier checks current Apple status, product, expiry and account binding', async () => {
  const f = appleFixture(); assert.equal((await f.verify('proof', account)).active, true); assert.equal(f.requests, 1);
  for (const options of [{ owner: 'other' }, { status: 5 }, { status: 2 }, { revoked: now() }, { product: 'other' }, { expired: true }, { forged: true }]) {
    const bad = appleFixture(options); assert.equal(await bad.verify('proof', account), null);
  }
  await assert.rejects(appleFixture({ serverFailure: true }).verify('proof', account), SubscriptionUnavailable);
  const unconfigured = createAppleSubscriptionVerifier({ env: {} }); await assert.rejects(unconfigured('proof', account), SubscriptionUnavailable);
});

function socketFixture({ transcript = 'Hello.', abort } = {}) {
  const sent = []; let closed = false;
  class Socket extends EventEmitter {
    send(raw) {
      const value = JSON.parse(raw); sent.push(value);
      queueMicrotask(() => {
        if (value.type === 'session.update') this.emit('message', JSON.stringify({ type: 'session.updated' }));
        else {
          if (abort) { abort.abort(); return; }
          for (const event of [{ type: 'response.output_audio.delta', delta: Buffer.alloc(48).toString('base64') },
            { type: 'response.output_audio_transcript.delta', delta: transcript }, { type: 'response.done', response: { status: 'completed' } }]) this.emit('message', JSON.stringify(event));
        }
      });
    }
    close() { closed = true; this.emit('close'); }
  }
  return { sent, get closed() { return closed; }, factory(url, options) {
    assert.match(url, /gpt-realtime-2.1-mini/); assert.equal(options.headers.Authorization, 'Bearer secret');
    const s = new Socket(); queueMicrotask(() => s.emit('message', JSON.stringify({ type: 'session.created' }))); return s;
  } };
}
test('Realtime voice frames become bounded 24kHz mono WAV only after matching the requested words', async () => {
  const f = socketFixture(); const wav = await realtimeSpeech({ text: 'Hello.', voice: 'marin', env, signal: new AbortController().signal, socketFactory: f.factory });
  assert.equal(wav.toString('ascii', 0, 4), 'RIFF'); assert.equal(wav.readUInt32LE(24), 24000); assert.equal(wav.length, 92); assert.equal(f.closed, true);
  assert.deepEqual(f.sent[0].session.tools, []); assert.equal(f.sent[1].response.conversation, 'none');
  const mismatch = socketFixture({ transcript: 'I booked an Uber.' });
  await assert.rejects(realtimeSpeech({ text: 'Hello.', voice: 'marin', env, signal: new AbortController().signal, socketFactory: mismatch.factory }), /voice_text_mismatch/);
});
test('cancelling pending cloud speech closes its upstream socket', async () => {
  const abort = new AbortController(); const f = socketFixture({ abort });
  await assert.rejects(realtimeSpeech({ text: 'Hello.', voice: 'marin', env, signal: abort.signal, socketFactory: f.factory }), /cancelled/);
  assert.equal(f.closed, true);
});

test('Realtime failures retain approved diagnostics without provider messages', async () => {
  for (const event of [
    { type: 'error', error: { code: 'insufficient_quota', message: 'private text' } },
    { type: 'response.done', response: { status: 'failed', status_details: { error: { code: 'insufficient_quota', message: 'private text' } } } },
  ]) {
    await assert.rejects(realtimeSpeech({ text: 'Hello.', voice: 'marin', env,
      signal: new AbortController().signal,
      socketFactory: () => {
        const s = new EventEmitter(); s.close = () => {};
        queueMicrotask(() => s.emit('message', JSON.stringify(event))); return s;
      },
    }), error => error.providerCode === 'insufficient_quota' && !error.message.includes('private'));
  }
});
