export const apiError = (status, error, code) => Response.json({ error, ...(code ? { code } : {}) }, { status, headers: { 'Cache-Control': 'no-store' } });

export async function authorizeMax({ request, env, fetchImpl, verifyPaid, now, signal, proof }) {
  let base;
  try {
    const url = new URL(env.SUPABASE_URL);
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || !env.SUPABASE_ANON_KEY?.trim()) throw Error();
    base = url.href.replace(/\/$/, '');
  } catch { return { error: apiError(503, 'Max is not connected yet.') }; }
  const authorization = request.headers.get('authorization');
  if (!authorization?.match(/^Bearer [^\s]+$/)) return { error: apiError(401, 'Sign in to talk with Max.') };
  const headers = { apikey: env.SUPABASE_ANON_KEY, Authorization: authorization };
  const response = await fetchImpl(base + '/auth/v1/user', { headers, signal });
  if (!response.ok) return { error: apiError([401, 403].includes(response.status) ? 401 : 503, 'Please sign in again.') };
  const user = await response.json();
  if (typeof user?.id !== 'string' || !user.id || typeof user.is_anonymous !== 'boolean') return { error: apiError(503, 'Your account could not be verified.') };
  if (user.is_anonymous) {
    const created = typeof user.created_at === 'string' ? Date.parse(user.created_at) : NaN;
    if (!Number.isFinite(created) || created > now()) return { error: apiError(503, 'Your demo could not be verified.') };
    if (now() >= created + 7 * 86400000) return { error: apiError(402, 'Your seven-day demo has ended.', 'demo_expired') };
    return { user, headers, base, subscription: null };
  }
  const subscription = await verifyPaid(proof ?? request.headers.get('x-max-transaction'), user.id);
  if (!subscription?.active) return { error: apiError(402, 'An active Max subscription is required.', 'subscription_required') };
  return { user, headers, base, subscription };
}

export async function readJSON(request, maxBytes) {
  if (!request.headers.get('content-type')?.includes('application/json')) return { error: apiError(415, 'Use JSON') };
  try {
    const chunks = []; let size = 0;
    for await (const chunk of request.body ?? []) {
      size += chunk.byteLength;
      if (size > maxBytes) return { error: apiError(413, 'Request is too large') };
      chunks.push(chunk);
    }
    const body = JSON.parse(new TextDecoder().decode(Uint8Array.from(chunks.flatMap(c => Array.from(c)))));
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw Error();
    return { body };
  } catch { return { error: apiError(400, 'Invalid JSON') }; }
}
