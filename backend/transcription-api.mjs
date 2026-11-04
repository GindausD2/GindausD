import { Buffer } from 'node:buffer';
import { authorizeMax, apiError } from './access.mjs';
import { providerResponseCode } from './provider-errors.mjs';
import { SubscriptionUnavailable } from './apple-subscriptions.mjs';

// The native capture sends only bounded 16 kHz, mono, PCM16 WAV. No client model,
// prompt, draft, language override or translation operation is accepted.
// Optional literal vocabulary hints are strictly validated, never instructions.
export const MAX_TRANSCRIPTION_BYTES = 44 + 16000 * 2 * 120;
export const VERBATIM_PROMPT = 'Verbatim speech with filler words (um, uh, like), repetitions, false starts and self-corrections preserved. Original spoken languages and wording, including code switching. No translation, paraphrase, summary, grammar correction or unspoken words.';

function validWave(wav) {
  return wav.length >= 44 + 3200 && wav.length <= MAX_TRANSCRIPTION_BYTES &&
    wav.toString('ascii', 0, 4) === 'RIFF' && wav.readUInt32LE(4) === wav.length - 8 &&
    wav.toString('ascii', 8, 16) === 'WAVEfmt ' && wav.readUInt32LE(16) === 16 &&
    wav.readUInt16LE(20) === 1 && wav.readUInt16LE(22) === 1 &&
    wav.readUInt32LE(24) === 16000 && wav.readUInt32LE(28) === 32000 &&
    wav.readUInt16LE(32) === 2 && wav.readUInt16LE(34) === 16 &&
    wav.toString('ascii', 36, 40) === 'data' && wav.readUInt32LE(40) === wav.length - 44 &&
    (wav.length - 44) % 2 === 0;
}

export function createTranscriptionAPI({ env, fetchImpl, now, verifyPaid, log }) {
  return async request => {
    if (new URL(request.url).pathname !== '/v1/transcriptions') return null;
    if (request.method !== 'POST') return apiError(405, 'Use POST');
    if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'audio/wav') return apiError(415, 'Use PCM WAV audio');
    if (!env.OPENAI_API_KEY?.trim()) return apiError(503, 'Max transcription is not connected yet.');
    const signal = AbortSignal.any([request.signal, AbortSignal.timeout(45000)]);
    try {
      const access = await authorizeMax({ request, env, fetchImpl, now, verifyPaid, signal });
      if (access.error) return access.error;
      let vocabulary = [];
      const encodedHints = request.headers.get('x-max-vocabulary');
      if (encodedHints !== null) {
        try {
          if (encodedHints.length > 12000 || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encodedHints)) throw Error();
          vocabulary = JSON.parse(Buffer.from(encodedHints, 'base64').toString('utf8'));
          if (!Array.isArray(vocabulary) || vocabulary.length > 25 || vocabulary.some(word => typeof word !== 'string' || !word.trim() || [...word].length > 64 || /[<>\p{Cc}]/u.test(word)) || new Set(vocabulary.map(word => word.toLowerCase())).size !== vocabulary.length) throw Error();
        } catch { return apiError(400, 'Use up to 25 distinct vocabulary hints of 1–64 characters, without line breaks or angle brackets.'); }
      }
      const chunks = []; let bytes = 0;
      for await (const chunk of request.body ?? []) {
        bytes += chunk.byteLength;
        if (bytes > MAX_TRANSCRIPTION_BYTES) return apiError(413, 'Record up to two minutes at a time.');
        chunks.push(chunk);
      }
      signal.throwIfAborted();
      const wav = Buffer.concat(chunks);
      if (!validWave(wav)) return apiError(400, 'Use a complete 16 kHz mono PCM16 recording of up to two minutes.');
      // Digital silence must not become an invented sentence or spend a quota unit.
      let peak = 0;
      for (let offset = 44; offset < wav.length; offset += 2) peak = Math.max(peak, Math.abs(wav.readInt16LE(offset)));
      if (peak < 32) return Response.json({ text: '' }, { headers: { 'Cache-Control': 'no-store' } });
      // Reuse the server-owned daily request budget; no new privileged SQL or
      // separate unlimited provider path is introduced.
      const quota = await fetchImpl(access.base + '/rest/v1/rpc/consume_max_request', {
        method: 'POST', headers: { ...access.headers, 'Content-Type': 'application/json' }, body: '{}', signal,
      });
      if (!quota.ok) return apiError(503, 'Max transcription is temporarily unavailable.');
      const allowed = await quota.json();
      if (allowed === false) return apiError(429, 'Your transcription request limit has been reached.', 'transcription_limit');
      if (allowed !== true) return apiError(503, 'Max transcription is temporarily unavailable.');
      const form = new FormData();
      form.set('file', new Blob([wav], { type: 'audio/wav' }), 'dictation.wav');
      form.set('model', env.OPENAI_TRANSCRIBE_MODEL || 'gpt-transcribe');
      form.set('prompt', VERBATIM_PROMPT);
      for (const word of vocabulary) form.append('keywords[]', word);
      const upstream = await fetchImpl('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST', headers: { Authorization: 'Bearer ' + env.OPENAI_API_KEY }, body: form, signal,
      });
      if (!upstream.ok) {
        log('Max transcription provider failed', { status: upstream.status, code: await providerResponseCode(upstream) });
        return apiError(upstream.status === 429 ? 429 : 502, 'Max could not finish transcribing. Review the iPhone draft or try again.');
      }
      const result = await upstream.json();
      if (typeof result?.text !== 'string' || result.text.length > 24000) return apiError(502, 'Max could not finish transcribing.');
      // GPT-Transcribe reports [] when no language can be reliably identified.
      const text = Array.isArray(result.languages) && result.languages.length === 0 ? '' : result.text;
      // Return the recognizer output directly. A text model never rewrites it.
      return Response.json({ text }, { headers: { 'Cache-Control': 'no-store' } });
    } catch (error) {
      if (request.signal.aborted) return apiError(499, 'Transcription stopped');
      log('Max transcription failed', { name: error?.name || 'Error' });
      return apiError(error instanceof SubscriptionUnavailable ? 503 : 502, 'Max could not finish transcribing. Please try again.');
    }
  };
}
