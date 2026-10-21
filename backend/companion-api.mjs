import { authorizeMax, apiError, readJSON } from './access.mjs';
import { createAppleSubscriptionVerifier, SubscriptionUnavailable } from './apple-subscriptions.mjs';
import { realtimeSpeech } from './realtime-speech.mjs';

export function createCompanionAPI({ env = process.env, fetchImpl = fetch, now = Date.now,
  verifyPaid = createAppleSubscriptionVerifier({ env, now }), speak = realtimeSpeech } = {}) {
  return async request => {
    const path = new URL(request.url).pathname;
    if (!['/v1/speech', '/v1/subscription'].includes(path)) return null;
    if (request.method !== 'POST') return apiError(405, 'Use POST');
    const parsed = await readJSON(request, 24000);
    if (parsed.error) return parsed.error;
    const body = parsed.body;
    const speech = path === '/v1/speech';
    if (speech && (typeof body.text !== 'string' || !body.text.trim() || body.text.length > 1000 || !['marin', 'cedar'].includes(body.voice))) return apiError(400, 'Use a supported voice and up to 1,000 characters.');
    if (speech && !env.OPENAI_API_KEY?.trim()) return apiError(503, 'Max voice is not connected yet.');
    const signal = AbortSignal.any([request.signal, AbortSignal.timeout(45000)]);
    try {
      const access = await authorizeMax({ request, env, fetchImpl, verifyPaid, now, signal,
        ...(speech ? {} : { proof: body.signedTransaction ?? '' }) });
      if (access.error) return access.error;
      if (!speech) {
        if (!access.subscription) return apiError(402, 'Continue with Apple before subscribing.', 'subscription_required');
        return Response.json(access.subscription, { headers: { 'Cache-Control': 'no-store' } });
      }
      const quota = await fetchImpl(access.base + '/rest/v1/rpc/consume_max_voice', {
        method: 'POST', headers: { ...access.headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ characters: body.text.length }), signal,
      });
      if (!quota.ok) return apiError(503, 'Max voice is temporarily unavailable.');
      const allowed = await quota.json();
      if (allowed === false) return apiError(429, 'Your OpenAI voice limit has been reached. The iPhone voice is still available.', 'voice_limit');
      if (allowed !== true) return apiError(503, 'Max voice is temporarily unavailable.');
      const wav = await speak({ text: body.text, voice: body.voice, env, signal });
      return new Response(wav, { headers: { 'Content-Type': 'audio/wav', 'Cache-Control': 'no-store' } });
    } catch (error) {
      if (request.signal.aborted) return apiError(499, 'Playback stopped');
      return apiError(error instanceof SubscriptionUnavailable ? 503 : 502, 'Max could not verify access or play this voice. Please try again.');
    }
  };
}
