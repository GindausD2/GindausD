import { createHandler } from './handler.mjs';
import { createEdgeHandler } from './edge.mjs';

let publicKeys: Record<string, string> = {};
try { publicKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}'); } catch { /* Legacy runtime fallback below. */ }

const env = {
  OPENAI_API_KEY: Deno.env.get('OPENAI_API_KEY') ?? '',
  OPENAI_MODEL: Deno.env.get('OPENAI_MODEL') ?? 'gpt-5.4-mini',
  SUPABASE_URL: Deno.env.get('SUPABASE_URL') ?? '',
  SUPABASE_ANON_KEY: Deno.env.get('MAX_SUPABASE_PUBLIC_KEY') ?? publicKeys.default ?? Deno.env.get('SUPABASE_ANON_KEY') ?? '',
};

// Gateway JWT verification is disabled because this shared handler validates
// every conversation token with Supabase Auth /user before quota or OpenAI.
// Public /health exposes readiness only; it cannot generate AI responses.
Deno.serve(createEdgeHandler(createHandler({ env })));
