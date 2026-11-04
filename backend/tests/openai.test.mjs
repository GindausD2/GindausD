import test from 'node:test';
import assert from 'node:assert/strict';
import { openAIMessages, maxStream } from '../openai.mjs';
import { chunk, frame, textStream } from './openai-fixtures.mjs';
const tools = [{ name: 'save_note' }, { name: 'get_datetime' }];
const stream = async (raw, split = false) => {
  const bytes = new TextEncoder().encode(raw);
  const body = new ReadableStream({ start(c) { if (split) for (const byte of bytes) c.enqueue(Uint8Array.of(byte)); else c.enqueue(bytes); c.close(); } });
  return new Response(maxStream(body, tools, new AbortController().signal)).text();
};
test('native multi-tool continuation converts to OpenAI assistant/tool roles and keeps text', () => {
  const result = openAIMessages([
    { role: 'user', content: 'Save this', tool_calls: [{ bad: true }] },
    { role: 'assistant', content: [{ type: 'text', text: 'I will save it.' }, { type: 'tool_use', id: 'a', name: 'save_note', input: { title: 'Idea', content: '❄️' } }, { type: 'tool_use', id: 'b', name: 'get_datetime', input: {} }] },
    { role: 'user', content: [{ type: 'tool_result', tool_use_id: 'a', content: '{"saved":true}' }, { type: 'tool_result', tool_use_id: 'b', content: '2026-10-14' }] }
  ], 'Max rules');
  assert.deepEqual(result[0], { role: 'developer', content: 'Max rules' });
  assert.deepEqual(result[1], { role: 'user', content: 'Save this' });
  assert.equal(result[2].content, 'I will save it.');
  assert.deepEqual(JSON.parse(result[2].tool_calls[0].function.arguments), { title: 'Idea', content: '❄️' });
  assert.deepEqual(result.slice(3), [{ role: 'tool', tool_call_id: 'a', content: '{"saved":true}' }, { role: 'tool', tool_call_id: 'b', content: '2026-10-14' }]);
});
test('unmatched, missing, duplicate and incorrectly placed tool blocks are rejected', () => {
  const call = { type: 'tool_use', id: 'a', name: 'save_note', input: {} };
  const result = { type: 'tool_result', tool_use_id: 'a', content: 'saved' };
  for (const messages of [
    [{ role: 'user', content: [result] }],
    [{ role: 'assistant', content: [call] }],
    [{ role: 'user', content: [call] }],
    [{ role: 'assistant', content: [call, call] }, { role: 'user', content: [result] }],
    [{ role: 'assistant', content: [call] }, { role: 'assistant', content: [result] }]
  ]) assert.throws(() => openAIMessages(messages, 'rules'));
});
test('split Unicode, CRLF frames and refusals become valid native text and completion', async () => {
  const raw = textStream('Hello ❄️ — café').replaceAll('\n', '\r\n');
  const output = await stream(raw, true);
  assert.match(output, /Hello ❄️ — café/); assert.match(output, /end_turn/); assert.match(output, /message_stop/);
  const refusal = await stream(frame(chunk({ refusal: 'I cannot help with that.' })) + frame(chunk({}, 'stop')) + frame('[DONE]'));
  assert.match(refusal, /I cannot help/); assert.match(refusal, /message_stop/);
});
test('interleaved tool fragments emit complete serialized blocks for the native parser', async () => {
  const raw = [
    chunk({ content: 'One moment.' }),
    chunk({ tool_calls: [{ index: 1, id: 'b', type: 'function', function: { name: 'get_datetime', arguments: '{' } }, { index: 0, id: 'a', type: 'function', function: { name: 'save_', arguments: '{"title":"Idea",' } }] }),
    chunk({ tool_calls: [{ index: 0, function: { name: 'note', arguments: '"content":"❄️"}' } }, { index: 1, function: { arguments: '}' } }] }),
    chunk({}, 'tool_calls')
  ].map(frame).join('') + frame('[DONE]');
  const output = await stream(raw, true);
  const events = output.split('\n').filter(l => l.startsWith('data: ')).map(l => JSON.parse(l.slice(6)));
  assert.deepEqual(events.filter(e => e.type === 'content_block_start').map(e => e.content_block.name), ['save_note', 'get_datetime']);
  assert.deepEqual(JSON.parse(events[2].delta.partial_json), { title: 'Idea', content: '❄️' });
  assert.equal(events.at(-2).delta.stop_reason, 'tool_use');
  assert.equal(events.at(-1).type, 'message_stop');
});
test('truncation, incomplete streams, malformed events and provider errors never complete', async () => {
  for (const raw of [frame(chunk({ content: 'partial' })), frame(chunk({}, 'length')) + frame('[DONE]'), frame('[DONE]'), 'data: not-json\n\n', frame({ error: { message: 'secret-provider-detail' } })]) {
    const output = await stream(raw);
    assert.match(output, /event: error/); assert.doesNotMatch(output, /message_stop|secret-provider-detail/);
  }
});
test('unknown, malformed and duplicate tool calls cannot execute even after provider completion', async () => {
  for (const calls of [
    [{ index: 0, id: 'a', function: { name: 'book_uber', arguments: '{}' } }],
    [{ index: 0, id: 'a', function: { name: 'save_note', arguments: '{broken' } }],
    [{ index: 0, id: 'a', function: { name: 'save_note', arguments: '[]' } }],
    [{ index: 0, id: 'a', function: { name: 'save_note', arguments: '{}' } }, { index: 1, id: 'a', function: { name: 'get_datetime', arguments: '{}' } }]
  ]) {
    const output = await stream(frame(chunk({ tool_calls: calls })) + frame(chunk({}, 'tool_calls')) + frame('[DONE]'));
    assert.match(output, /event: error/); assert.doesNotMatch(output, /content_block_start|message_stop/);
  }
});
test('consumer cancellation cancels the upstream reader', async () => {
  let cancelled = false;
  const upstream = new ReadableStream({ start(c) { c.enqueue(new TextEncoder().encode(frame(chunk({ content: 'Hello' })))); }, cancel() { cancelled = true; } });
  const reader = maxStream(upstream, [], new AbortController().signal).getReader();
  await reader.read(); await reader.cancel(); assert.equal(cancelled, true);
});
