import test from 'node:test';
import assert from 'node:assert/strict';
import { createVisualAPI } from '../visual-api.mjs';

const time = Date.parse('2026-11-09T08:00:00Z');
const env = { SUPABASE_URL: 'https://auth.example', SUPABASE_ANON_KEY: 'public', OPENAI_API_KEY: 'server-only' };
const jpeg = Buffer.from([255, 216, 255, 0, 255, 217]).toString('base64');
const request = (body, token = true) => new Request('https://max.example/v1/visual', {
  method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer session' } : {}) },
  body: JSON.stringify(body),
});
const fixture = ({ allowed = true } = {}) => {
  const calls = [];
  const handle = createVisualAPI({ env, now: () => time, verifyPaid: async () => null,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/auth/v1/user')) {
        return Response.json({ id: 'demo', is_anonymous: true, created_at: '2026-11-08T08:00:00Z' });
      }
      if (url.endsWith('/consume_max_request')) return Response.json(allowed);
      return Response.json({ choices: [{ message: { content: 'Answer from the provider' } }] });
    },
  });
  return { handle, calls };
};

test('visual recognition forwards only a bounded JPEG and question', async () => {
  const { handle, calls } = fixture();
  const response = await handle(request({ mode: 'identify', jpeg, text: 'What animal is this?' }));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal((await response.json()).answer, 'Answer from the provider');
  assert.equal(calls.length, 3);
  const payload = JSON.parse(calls[2].options.body);
  assert.equal(payload.store, false);
  assert.equal(payload.messages[1].content[1].image_url.url, 'data:image/jpeg;base64,' + jpeg);
});

test('speech translation sends only text and keeps the requested language', async () => {
  const { handle, calls } = fixture();
  assert.equal((await handle(request({ mode: 'translateSpeech', text: 'Bonjour', language: 'Hausa' }))).status, 200);
  const payload = JSON.parse(calls[2].options.body);
  assert.match(payload.messages[0].content, /Hausa/);
  assert.deepEqual(payload.messages[1].content, [{ type: 'text', text: 'Bonjour' }]);
});

test('invalid images and missing identity never reach the provider', async () => {
  const { handle, calls } = fixture();
  assert.equal((await handle(request({ mode: 'translatePhoto', jpeg: 'aW52YWxpZA==', language: 'English', text: '' }))).status, 400);
  assert.equal((await handle(request({ mode: 'identify', jpeg, text: '' }, false))).status, 401);
  assert.equal(calls.length, 0);
});

test('quota denial prevents a provider request', async () => {
  const { handle, calls } = fixture({ allowed: false });
  assert.equal((await handle(request({ mode: 'translatePhoto', jpeg, language: 'French', text: '' }))).status, 429);
  assert.equal(calls.length, 2);
});
