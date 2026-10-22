import test from 'node:test';
import assert from 'node:assert/strict';
import { providerResponseCode, safeProviderCode } from '../provider-errors.mjs';

test('diagnostics retain only approved error codes, never provider messages', async () => {
  assert.equal(await providerResponseCode(Response.json({ error: {
    code: 'insufficient_quota', message: 'Private conversation and secret key',
  } })), 'insufficient_quota');
  for (const value of ['secret-key', 'private user text', { code: 'invalid_api_key' }, null]) {
    assert.equal(safeProviderCode(value), 'unknown');
  }
  assert.equal(await providerResponseCode(Response.json({ error: { code: 'secret-key' } })), 'unknown');
});

test('malformed and excessive diagnostic bodies are bounded and discarded', async () => {
  assert.equal(await providerResponseCode(new Response('not JSON')), 'unknown');
  assert.equal(await providerResponseCode(new Response('x'.repeat(16385))), 'unknown');
  assert.equal(await providerResponseCode(new Response(null, { status: 502 })), 'unknown');
});
