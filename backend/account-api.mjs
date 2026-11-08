import { Buffer } from 'node:buffer';
import { apiError, readJSON } from './access.mjs';

const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;

/** @param {{env: Record<string, string | undefined>, fetchImpl: typeof fetch}} options */
export function createAccountAPI({ env, fetchImpl }) {
  return async function accountAPI(request) {
    if (new URL(request.url).pathname !== '/v1/account/delete') return null;
    if (request.method !== 'POST') return apiError(405, 'Use POST.');
    const authorization = request.headers.get('authorization');
    if (!authorization?.match(/^Bearer [^\s]+$/)) return apiError(401, 'Sign in again to delete your account.');
    const parsed = await readJSON(request, 8192);
    if (parsed.error) return parsed.error;
    const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY?.trim();
    let base;
    try {
      const url = new URL(env.SUPABASE_URL || '');
      if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || !serviceKey || !env.SUPABASE_ANON_KEY) throw Error();
      base = url.href.replace(/\/$/, '');
    } catch { return apiError(503, 'Account deletion is temporarily unavailable.'); }

    const signal = AbortSignal.timeout(35000);
    try {
      const identity = await fetchImpl(base + '/auth/v1/user', {
        headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: authorization }, signal,
      });
      if (!identity.ok) return apiError([401, 403].includes(identity.status) ? 401 : 503, 'Max could not verify your account.');
      const user = await identity.json();
      if (typeof user.id !== 'string' || !uuid.test(user.id) || typeof user.is_anonymous !== 'boolean') {
        return apiError(503, 'Max could not verify your account.');
      }

      if (!user.is_anonymous) {
        const code = parsed.body.appleCode;
        if (typeof code !== 'string' || !code.trim() || code.length > 4096) {
          return apiError(400, 'Confirm your identity with Apple to continue.');
        }
        const clientID = env.MAX_APPLE_SIGN_IN_CLIENT_ID?.trim();
        const clientSecret = env.MAX_APPLE_SIGN_IN_CLIENT_SECRET?.trim();
        const appleIdentity = Array.isArray(user.identities) && user.identities.find(item => item?.provider === 'apple');
        const subject = appleIdentity?.identity_data?.sub ?? appleIdentity?.identity_id ?? appleIdentity?.id;
        if (!clientID || !clientSecret || typeof subject !== 'string' || !subject) {
          return apiError(503, 'Apple account deletion is temporarily unavailable.');
        }

        const form = (path, values) => fetchImpl('https://appleid.apple.com/auth/' + path, {
          method: 'POST', signal, headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ client_id: clientID, client_secret: clientSecret, ...values }),
        });
        const exchanged = await form('token', { code, grant_type: 'authorization_code' });
        if (!exchanged.ok) return apiError(409, 'Apple could not confirm this request. Try again.');
        const tokens = await exchanged.json();
        // The ID token is returned directly by Apple's authenticated HTTPS token endpoint.
        const claims = JSON.parse(Buffer.from(tokens.id_token.split('.')[1], 'base64url').toString('utf8'));
        if (claims.iss !== 'https://appleid.apple.com' || claims.aud !== clientID || claims.sub !== subject) {
          return apiError(403, 'Use the same Apple Account you used to sign into Max.');
        }
        const token = tokens.refresh_token || tokens.access_token;
        if (typeof token !== 'string' || !token) return apiError(503, 'Apple did not provide a token to revoke.');
        const revoked = await form('revoke', { token, token_type_hint: tokens.refresh_token ? 'refresh_token' : 'access_token' });
        if (!revoked.ok) return apiError(502, 'Apple could not revoke access. Try again.');
      }

      // Delete only the identity returned by /auth/v1/user. The client never supplies a user ID.
      const deletion = await fetchImpl(base + '/auth/v1/admin/users/' + user.id, {
        method: 'DELETE', headers: { apikey: serviceKey, Authorization: 'Bearer ' + serviceKey }, signal,
      });
      if (!deletion.ok && deletion.status !== 404) return apiError(502, 'Max could not finish deleting your account. Try again.');
      return new Response(null, { status: 204, headers: { 'Cache-Control': 'no-store' } });
    } catch { return apiError(502, 'Max could not finish deleting your account. Try again.'); }
  };
}
