# Max — The AI Companion

Max is a personal companion for conversations, daily briefings, reminders, and memories you choose to save. V1 focuses on the native iPhone app and Dynamic Island, with a premium glacier-blue glass interface. Flight/Uber booking and advanced autonomous agents are outside V1.

The native implementation uses Apple speech recognition, optional OpenAI voice playback and iPhone text-to-speech fallback. OpenAI generation goes through an authenticated Max backend hosted as a Supabase Edge Function; users do not enter provider API keys. Local notes, saved places, reminder forms, and conversation history can be used without AI generation.

## Project paths

- `ios-swift/`: native iPhone app, Dynamic Island extension, home/lock-screen widget, and XcodeGen project specification.
- `backend/`: authenticated streaming endpoint, V1 tool allowlist, usage-quota SQL migration, and focused server tests.
- `app/`, `components/`, `hooks/`, `services/`: Expo design preview. Its older direct-provider/auth paths are not the native V1 release path.
- `android-kotlin/`: earlier Android prototype; not yet brought to native iPhone V1 parity.
- `docs/V1_STATUS.md`: exact source status, required setup, limitations, and device acceptance checks.

## Brand artwork

`branding/` contains the supplied Max logo reference, scalable SVG, transparent black/white PNGs and the reproducible import script. The native app icon, launch screen, shared logo component, entry headers and widget identity use this mark. The blue orb stays the voice control.

See [the 21 October release update](docs/RELEASE_SETUP.md) for the chosen $4.99 monthly launch price, implemented source changes, exact checks and remaining live setup. The new voice and subscription endpoints are deployed to a separate [Sandbox beta service](docs/BETA_SETUP.md); the Production endpoint is unchanged.

## Validation

```bash
npm ci --prefix backend
node --test backend/tests/*.test.mjs
npx --yes deno@2.9.6 check --config backend/deno.json backend/supabase-index.ts
npx --yes deno@2.9.6 test --config backend/deno.json --allow-net=127.0.0.1 --allow-env=WS_NO_BUFFER_UTIL,WS_NO_UTF_8_VALIDATE backend/tests/edge-runtime.test.ts
npm ci
npx tsc --noEmit
```

For the deployed endpoint and remaining OpenAI secret, see [OpenAI setup](docs/OPENAI_SETUP.md).

For native generation/build setup and the server environment, follow [V1 status and setup](docs/V1_STATUS.md). Xcode and live account/provider credentials are required to validate the release. No production-ready or always-on assistant is claimed by the prototype.
