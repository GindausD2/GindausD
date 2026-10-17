// Preserve Max's native block/SSE contract while using OpenAI Chat Completions.
export function openAIMessages(messages, system) {
  const output = [{ role: 'developer', content: system }], pending = new Set(), seen = new Set();
  for (const message of messages) {
    if (typeof message.content === 'string') {
      if (pending.size) throw Error('Missing tool results');
      output.push({ role: message.role, content: message.content }); continue;
    }
    const calls = message.content.filter(b => b.type === 'tool_use');
    const results = message.content.filter(b => b.type === 'tool_result');
    const content = message.content.filter(b => b.type === 'text').map(b => b.text).join('\n');
    if (calls.length) {
      if (message.role !== 'assistant' || results.length || pending.size) throw Error('Invalid tool calls');
      const tool_calls = calls.map(call => {
        if (!call.id.trim() || seen.has(call.id)) throw Error('Duplicate tool call');
        pending.add(call.id); seen.add(call.id);
        return { id: call.id, type: 'function', function: { name: call.name, arguments: JSON.stringify(call.input) } };
      });
      output.push({ role: 'assistant', content: content || null, tool_calls });
    } else if (results.length) {
      if (message.role !== 'user') throw Error('Invalid tool results');
      for (const result of results) {
        if (!pending.delete(result.tool_use_id)) throw Error('Unmatched tool result');
        output.push({ role: 'tool', tool_call_id: result.tool_use_id, content: result.content });
      }
      if (content) {
        if (pending.size) throw Error('Missing tool results');
        output.push({ role: 'user', content });
      }
    } else {
      if (pending.size) throw Error('Missing tool results');
      output.push({ role: message.role, content });
    }
  }
  if (pending.size) throw Error('Missing tool results');
  return output;
}

const encode = event => new TextEncoder().encode(`event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`);
export function maxStream(upstream, tools, signal) {
  const reader = upstream.getReader(), allowed = new Set(tools.map(t => t.name));
  let cancelled = false;
  const abort = () => { reader.cancel(signal.reason).catch(() => {}); };
  signal.addEventListener('abort', abort, { once: true });
  if (signal.aborted) abort();
  async function* events() {
    const decoder = new TextDecoder('utf-8', { fatal: true });
    let buffer = '', total = 0, finish = null, done = false;
    const calls = new Map(), ids = new Set();
    try {
      while (!done) {
        const chunk = await reader.read();
        if (signal.aborted) throw Error('Aborted');
        buffer += decoder.decode(chunk.value, { stream: !chunk.done });
        total += chunk.value?.byteLength || 0;
        if (total > 1048576 || buffer.length > 131072) throw Error('Oversized stream');
        let separator;
        while ((separator = /\r?\n\r?\n/.exec(buffer))) {
          const frame = buffer.slice(0, separator.index);
          buffer = buffer.slice(separator.index + separator[0].length);
          const data = frame.split(/\r?\n/).filter(line => line.startsWith('data:')).map(line => line.slice(5).trimStart()).join('\n');
          if (!data) continue;
          if (data === '[DONE]') { done = true; break; }
          const event = JSON.parse(data);
          if (event.error || !Array.isArray(event.choices)) throw Error('Invalid provider event');
          if (!event.choices.length) continue;
          const choice = event.choices.find(c => c.index === 0);
          if (!choice || finish) throw Error('Invalid provider choice');
          const delta = choice.delta || {};
          for (const text of [delta.content, delta.refusal]) {
            if (text != null) {
              if (typeof text !== 'string') throw Error('Invalid text');
              if (text) yield { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text } };
            }
          }
          for (const part of delta.tool_calls || []) {
            if (!Number.isInteger(part.index) || part.index < 0 || part.index >= 14 || (part.type && part.type !== 'function')) throw Error('Invalid tool');
            const call = calls.get(part.index) || { id: '', name: '', arguments: '' };
            for (const [field, value] of [['id', part.id], ['name', part.function?.name], ['arguments', part.function?.arguments]]) {
              if (value != null) {
                if (typeof value !== 'string') throw Error('Invalid tool field');
                call[field] += value;
              }
            }
            if (call.id.length > 200 || call.name.length > 64 || call.arguments.length > 24000) throw Error('Oversized tool');
            calls.set(part.index, call);
          }
          if (choice.finish_reason != null) finish = choice.finish_reason;
        }
        if (chunk.done && !done) throw Error('Incomplete stream');
      }
      if (!['stop', 'tool_calls'].includes(finish) || (finish === 'stop' && calls.size) || (finish === 'tool_calls' && !calls.size)) throw Error('Incomplete reply');
      // Validate all calls first, then serialize blocks for the native parser.
      const completed = [...calls.entries()].sort((a, b) => a[0] - b[0]).map(([, call]) => {
        const input = JSON.parse(call.arguments || '{}');
        if (!call.id.trim() || ids.has(call.id) || !allowed.has(call.name) || !input || typeof input !== 'object' || Array.isArray(input)) throw Error('Invalid tool call');
        ids.add(call.id);
        return { ...call, arguments: JSON.stringify(input) };
      });
      for (let i = 0; i < completed.length; i++) {
        const call = completed[i], index = i + 1;
        yield { type: 'content_block_start', index, content_block: { type: 'tool_use', id: call.id, name: call.name, input: {} } };
        yield { type: 'content_block_delta', index, delta: { type: 'input_json_delta', partial_json: call.arguments } };
        yield { type: 'content_block_stop', index };
      }
      yield { type: 'message_delta', delta: { stop_reason: completed.length ? 'tool_use' : 'end_turn' } };
      yield { type: 'message_stop' };
    } catch {
      if (!cancelled && !signal.aborted) yield { type: 'error', error: { message: 'Max could not finish that reply. Please try again.' } };
    } finally {
      signal.removeEventListener('abort', abort);
      await reader.cancel().catch(() => {});
      reader.releaseLock();
    }
  }
  const iterator = events();
  return new ReadableStream({
    async pull(controller) {
      const next = await iterator.next();
      if (cancelled) return;
      if (next.done) controller.close(); else controller.enqueue(encode(next.value));
    },
    async cancel(reason) {
      cancelled = true;
      await reader.cancel(reason).catch(() => {});
      await iterator.return();
    }
  });
}
