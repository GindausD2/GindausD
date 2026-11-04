// Only fixed provider codes may enter logs; never log provider messages or payloads.
const codes = new Set(['insufficient_quota', 'credit_balance_exhausted',
  'organization_usage_limit_exceeded', 'project_spend_limit_exceeded',
  'rate_limit_exceeded', 'slow_down', 'invalid_api_key', 'model_not_found',
  'permission_denied', 'invalid_request_error', 'server_error']);
export const safeProviderCode = value => typeof value === 'string' && codes.has(value) ? value : 'unknown';

export async function providerResponseCode(response) {
  if (!response.body) return 'unknown';
  const reader = response.body.getReader();
  const chunks = []; let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 16384) return 'unknown';
      chunks.push(value);
    }
    const bytes = new Uint8Array(size); let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    const body = JSON.parse(new TextDecoder().decode(bytes));
    return safeProviderCode(body?.error?.code);
  } catch { return 'unknown'; }
  finally { await reader.cancel().catch(() => {}); reader.releaseLock(); }
}
