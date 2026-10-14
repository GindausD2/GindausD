# Max — The AI Companion

Max is a personal companion for conversations, daily briefings, reminders, and memories you choose to save. V1 focuses on the native iPhone app and Dynamic Island, with a premium glacier-blue glass interface. Flight/Uber booking and advanced autonomous agents are outside V1.

The native implementation uses Apple speech recognition and text-to-speech. OpenAI generation goes through an authenticated Max backend hosted as a Supabase Edge Function; users do not enter provider API keys. Local notes, saved places, reminder forms, and conversation history can be used without AI generation.

## Project paths

- `ios-swift/`: native iPhone app, Dynamic Island extension, home/lock-screen widget, and XcodeGen project specification.
- `backend/`: authenticated streaming endpoint, V1 tool allowlist, usage-quota SQL migration, and focused server tests.
- `app/`, `components/`, `hooks/`, `services/`: Expo design preview. Its older direct-provider/auth paths are not the native V1 release path.
- `android-kotlin/`: earlier Android prototype; not yet brought to native iPhone V1 parity.
- `docs/V1_STATUS.md`: exact source status, required setup, limitations, and device acceptance checks.

## Validation

```bash
node --test backend/tests/*.test.mjs
npm ci
npx tsc --noEmit
```

For the deployed endpoint and remaining OpenAI secret, see [OpenAI setup](docs/OPENAI_SETUP.md).

For native generation/build setup and the server environment, follow [V1 status and setup](docs/V1_STATUS.md). Xcode and live account/provider credentials are required to validate the release. No production-ready or always-on assistant is claimed by the prototype.
