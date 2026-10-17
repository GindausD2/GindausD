# Max OpenAI backend

## Deployed endpoint

Max now uses OpenAI Chat Completions through the `max-api` Supabase Edge Function in project `omcboajliacdnhrroijb`.

- Native base URL: `https://omcboajliacdnhrroijb.supabase.co/functions/v1/max-api`.
- Conversation route: `/v1/messages` appended to that base.
- Health route: `/health` appended to that base.
- `ios-swift/Configuration/Public.supabase.example.xcconfig` contains the actual base URL, Supabase project URL and active publishable key. Copy it to the ignored `Public.xcconfig` before your signed build.

On October 14, 2026, function version 2 was deployed and its live health endpoint returned HTTP 200 with `provider: openai`, `authConfigured: true` and `aiConfigured: false`. Conversation requests returned the expected HTTP 503 while the OpenAI secret was absent. This verifies deployment and missing-secret protection, not a real model response.

## Server secret configuration

1. Create a project API key in [OpenAI's API dashboard](https://platform.openai.com/api-keys), with API billing/model access enabled for that project.
2. Open [Supabase Edge Function secrets](https://supabase.com/dashboard/project/omcboajliacdnhrroijb/functions/secrets).
3. Add secret **`OPENAI_API_KEY`** with the key as its value and save. Enter it directly in the dashboard; do not put it in the mobile app, public configuration, source control, or a chat message.
4. Optional: set **`OPENAI_MODEL`** to another compatible Chat Completions model. The default is `gpt-5.4-mini`, verified against its current [official model documentation](https://developers.openai.com/api/docs/models/gpt-5.4-mini).

Supabase supplies `SUPABASE_URL` and its publishable-key map to Edge Functions; the entrypoint falls back to the injected legacy anon key on older runtimes. `MAX_SUPABASE_PUBLIC_KEY` can optionally override the latter with a modern publishable key. The shared Node server instead reads `OPENAI_API_KEY`, `OPENAI_MODEL`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY` from its server environment; use `backend/.env.example` for an independent Node 22+ deployment.

The user saved `OPENAI_API_KEY` on October 14, 2026. A fresh live check returned HTTP 200 with `aiConfigured: true` and `authConfigured: true`. A temporary, random-token-protected server-side check called OpenAI’s model-retrieval endpoint with the configured credential: OpenAI returned HTTP 200 and the configured model ID matched. The credential stayed inside Supabase. The temporary check was removed, the original function source was restored exactly (version 14), and normal health was verified again. This establishes credential acceptance and model lookup access, not Chat Completions permissions, available generation quota/billing, streaming or an authenticated native conversation.

For later secret changes, check health again. `aiConfigured: true` indicates a nonempty key is present, not that billing or model access is valid. The final acceptance test must use a real Apple/Supabase user session: authenticated request → quota RPC → OpenAI → streamed native text → successful reminder/memory tool continuation. Real microphone, spoken replies and haptics still require an iPhone test.

## Protocol and authentication

The backend keeps Max's existing `/v1/messages` request blocks and native SSE events. `backend/openai.mjs` translates ordinary messages, assistant function calls, and matching tool results into OpenAI roles. It converts streamed OpenAI text into native deltas, buffers and validates complete tool calls, and emits those calls serially for the native parser. Broken streams, malformed arguments, unknown tools and output-token truncation emit an error and cannot complete/execute partial actions. Disconnects cancel the upstream reader.

The server controls the model and the 2,048-token completion cap. Client model/token fields are ignored. Requests set `store: false`; that does not promise zero provider retention. Review [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data) for retention details. The native Settings links explicitly describe AI provider information; Max's own distribution policies still need to be finalized before a public launch.

The Edge Function uses `verify_jwt: false` at the gateway because the shared handler performs explicit authentication: every conversation bearer token is verified using Supabase `/auth/v1/user`, then passed to the quota RPC. No token is trusted merely because its claims decode. Missing/expired sessions, missing configuration, malformed quota responses and exhausted limits fail closed before OpenAI. `/health` is intentionally public and reveals no credentials. Do not remove the in-handler authentication.

Deployment source consists of `backend/supabase-index.ts`, `backend/edge.mjs`, `backend/handler.mjs`, and `backend/openai.mjs`. The Deno entrypoint is excluded from the Expo TypeScript project because it runs in Supabase's separate runtime; the shared server/adapter is covered by Node tests and the deployed endpoint smoke checks.

## Verification

- 29 backend tests pass: authenticated handling, quota failures, payload limits, message/tool translation, split Unicode/CRLF streaming, refusal text, interleaved calls, malformed/truncated streams, secret redaction, cancellation and Edge routing.
- Expo TypeScript check passes.
- Supabase function deploy/bundle and live health/missing-secret smoke checks pass.
- Native provider labels/data text were updated. `ClaudeService` retains its internal legacy name to preserve the native wire parser; it calls the Max server, never Anthropic. The separate Expo/Android prototypes remain outside this native migration.
- Live secret presence, OpenAI credential acceptance and configured-model lookup are verified. Unsigned conversation requests return HTTP 401.
- Real generated OpenAI responses, signed Apple login, generation permissions/billing/quota and physical iPhone behavior remain unverified until a signed app is tested with a real user session.
