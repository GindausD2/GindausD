import WebSocket from 'npm:ws@8.22.0';
import { createHandler } from '../handler.mjs';
import { realtimeSpeech } from '../realtime-speech.mjs';

Deno.test('Deno Edge handler plays WAV through a real local ws connection with fixture auth/provider', async () => {
  const sockets = new Set<globalThis.WebSocket>();
  let sessions = 0;
  const server = Deno.serve({ hostname: '127.0.0.1', port: 0, onListen() {} }, request => {
    const { socket, response } = Deno.upgradeWebSocket(request);
    sockets.add(socket);
    socket.onopen = () => socket.send(JSON.stringify({ type: 'session.created' }));
    socket.onclose = () => sockets.delete(socket);
    socket.onmessage = event => {
      const value = JSON.parse(event.data);
      if (value.type === 'session.update') socket.send(JSON.stringify({ type: 'session.updated' }));
      if (value.type === 'response.create') {
        sessions++;
        socket.send(JSON.stringify({ type: 'response.output_audio.delta', delta: btoa('\0'.repeat(48)) }));
        socket.send(JSON.stringify({ type: 'response.output_audio_transcript.delta', delta: 'Hello Max.' }));
        socket.send(JSON.stringify({ type: 'response.done', response: { status: 'completed' } }));
      }
    };
    return response;
  });
  try {
    const env = { OPENAI_API_KEY: 'fixture-only', SUPABASE_URL: 'https://fixture.invalid', SUPABASE_ANON_KEY: 'fixture-public' };
    const handle = createHandler({ env, now: () => Date.parse('2026-10-21T12:00:00Z'),
      fetchImpl: async (url: RequestInfo | URL) => {
        if (String(url).endsWith('/user')) return Response.json({ id: 'fixture', is_anonymous: true, created_at: '2026-10-20T12:00:00Z' });
        if (String(url).endsWith('/consume_max_voice')) return Response.json(true);
        throw new Error('Unexpected external request');
      },
      speak: (options: any) => realtimeSpeech({ ...options, socketFactory: () => new WebSocket(`ws://127.0.0.1:${server.addr.port}`) }),
    });
    const result = await handle(new Request('https://max.invalid/v1/speech', {
      method: 'POST', headers: { Authorization: 'Bearer fixture', 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: 'Hello Max.', voice: 'marin' }),
    }));
    if (result.status !== 200 || result.headers.get('content-type') !== 'audio/wav') throw new Error('Voice request failed');
    const bytes = new Uint8Array(await result.arrayBuffer());
    if (bytes.length !== 92 || new TextDecoder().decode(bytes.slice(0, 4)) !== 'RIFF' || sessions !== 1) throw new Error('Invalid WAV or session count');
  } finally {
    for (const socket of sockets) socket.close();
    await server.shutdown();
  }
});
