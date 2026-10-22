import { createHandler } from './handler.mjs';
import { createEdgeHandler } from './edge.mjs';
import { createAppleSubscriptionVerifier } from './apple-subscriptions.mjs';
import { realtimeSpeech } from './realtime-speech.mjs';
import * as apple from 'npm:@apple/app-store-server-library@3.1.0';
import WebSocket from 'npm:ws@8.22.0';

let publicKeys: Record<string, string> = {};
try { publicKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}'); } catch { /* Legacy runtime fallback below. */ }

const env = {
  OPENAI_API_KEY: Deno.env.get('OPENAI_API_KEY') ?? '',
  OPENAI_VOICE_MODEL: Deno.env.get('OPENAI_VOICE_MODEL') ?? 'gpt-realtime-2.1-mini',
  APPLE_STORE_ENVIRONMENT: Deno.env.get('APPLE_STORE_ENVIRONMENT') ?? 'Production',
  APPLE_IAP_KEY_ID: Deno.env.get('APPLE_IAP_KEY_ID') ?? '',
  APPLE_IAP_ISSUER_ID: Deno.env.get('APPLE_IAP_ISSUER_ID') ?? '',
  APPLE_IAP_PRIVATE_KEY: Deno.env.get('APPLE_IAP_PRIVATE_KEY') ?? '',
  APPLE_APP_ID: Deno.env.get('APPLE_APP_ID') ?? '',
  APPLE_ROOT_CERTIFICATES_BASE64: Deno.env.get('APPLE_ROOT_CERTIFICATES_BASE64') ?? '',
  OPENAI_MODEL: Deno.env.get('OPENAI_MODEL') ?? 'gpt-5.4-mini',
  SUPABASE_URL: Deno.env.get('SUPABASE_URL') ?? '',
  SUPABASE_ANON_KEY: Deno.env.get('MAX_SUPABASE_PUBLIC_KEY') ?? publicKeys.default ?? Deno.env.get('SUPABASE_ANON_KEY') ?? '',
};

// Gateway JWT verification is disabled because this shared handler validates
// every conversation token with Supabase Auth /user before quota or OpenAI.
// Public /health exposes readiness only; it cannot generate AI responses.
const verifyPaid = createAppleSubscriptionVerifier({ env, loadLibrary: async () => apple });
Deno.serve(createEdgeHandler(createHandler({ env, verifyPaid,
  speak: (options: any) => realtimeSpeech({ ...options,
    socketFactory: (url: string, settings: any) => new WebSocket(url, settings),
  }),
})));
