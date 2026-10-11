# Max V1 — The AI Companion

Release focus: the native iPhone app, with Dynamic Island as its identity. The Expo app remains the design preview; Expo and native Android are not yet equivalent release clients for these native V1 changes.

The native V1 beta is available after sign-in without a mandatory StoreKit purchase gate. Existing subscription code is retained but the purchase entry point is hidden from V1 Settings; server usage limits control AI generation.

Keep the premium glacier-blue glass design. Priorities are speed, personality, a useful daily ritual, and memory the user controls. Booking rides/flights, purchases, and advanced autonomous agents are excluded.

| Area | Implemented in source | Verification / remaining setup |
| --- | --- | --- |
| Voice | Native microphone/speech permissions, partial speech recognition, native spoken replies, voice selection, optional silence-ended continuous conversation while app is open, explicit stop and cancellation | Needs Xcode build and real-device testing. On-device recognition is preferred; Apple recognition may use its servers when unavailable locally. Not an always-listening background assistant. |
| Dynamic Island | Compact/expanded Live Activity views, glacier-blue accents, Talk / Briefing / Plan links opening Max, activation shortcut, lock-screen fallback | Needs extension build/signing and device testing. The system controls activity lifetime; this is not a permanent overlay across arbitrary apps. |
| Morning briefing | Scheduled local notification; on tap, builds a calendar / saved-place weather / pending-reminder snapshot; adds unread-important Gmail count when connected; local spoken fallback without AI | Not a system alarm or automatic background voice wake-up. WeatherKit capability and Gmail OAuth configuration are needed. Missed-call history is not supplied. Remote live pushes while closed are not configured. |
| Reminders | Future time validation, OS local notifications, arrival trigger at a manually saved place, context reminders surfaced when explicitly checked, manual creation/deletion | Geofencing accuracy/delivery and notification permissions require device testing. Context reminders do not monitor behavior in other apps. |
| Memory | Local notes, explicit facts/cards, manually saved addresses, conversation archive/timeline, per-account local storage scopes | Native persistence/account-switch tests still needed. Legacy unscoped data stays in local demo only. Navigation searches must not be represented as confirmed visits. |
| Managed AI | Native calls `/v1/messages` with an authenticated Supabase session; provider key stays on server; bounded native tool loop; standard tool-use/result protocol; cancellation; V1 allowlist; database-enforced usage quota | HTTP behavior has 9 passing mocked-dependency tests. Backend deployment, server environment, SQL migration, authentication config, real provider streaming, and database concurrency validation remain. |
| UI | Glacier-blue assistant control, warm glass surfaces, text input, Your day hub, Settings without API/client-ID entry, reduced-motion/transparency support | Expo builds were verified previously. Native Liquid Glass/layout/device interactions remain unverified. |

## Configure the native release

1. Use Xcode 26 on a Mac. Copy `ios-swift/Configuration/Public.example.xcconfig` to `Public.xcconfig` and set the public backend URL, Supabase URL/publishable key, signing team, and optional iOS Google OAuth client ID. Never add an Anthropic key to this file.
2. Install XcodeGen from its official source, run `xcodegen generate` in `ios-swift`, and open `Max.xcodeproj`. The spec supplies the app and two widget extension targets, shared attributes/logo source membership, app-group entitlements, Speech privacy text, URL schemes, Supabase dependency, and WeatherKit capability.
3. Configure Apple signing, App Group `group.com.gindausd.max`, Sign in with Apple, and WeatherKit for the app and relevant extensions. WeatherKit attribution is linked in the saved-places hub; verify required attribution presentation before distribution.
4. If enabling Gmail, configure the iOS Google OAuth client for bundle `com.gindausd.max` and custom callback `com.gindausd.max:/oauth2callback`, Gmail read-only scope, and authorized beta accounts/consent settings. The customer only taps Connect Gmail. Tokens are scoped by Max account and stored in Keychain; the authorization flow uses state and PKCE.
5. Generate/sign/build the project and complete the device checks below. The XcodeGen spec and Swift grammar were parsed here; neither project generation nor native compilation ran in this Linux environment.

## Configure the backend

1. In the same Supabase project as native sign-in, apply `backend/sql/001_usage.sql`. The RPC derives the user from `auth.uid()` and enforces 20 generation requests per minute and 100 per UTC day. Each continuation request counts. Clean older usage buckets on the database's maintenance schedule.
2. Set server-only `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` (optional), `SUPABASE_URL`, and `SUPABASE_ANON_KEY`. The anon/publishable key identifies the Supabase project; the customer's bearer token authenticates requests. A service-role key is not needed.
3. Run `npm start` from `backend` on Node 22+ and expose it behind HTTPS. No CORS/browser session integration is provided: this backend currently targets the native iPhone client.
4. Check `/health`, then verify real sign-in → authenticated `/v1/messages` → quota RPC → provider SSE → native text → spoken reply. Missing server configuration or quota installation fails closed.

## Device acceptance checks

- First microphone/speech permission, denied permission, speech unavailable, interrupted recording, backgrounding, explicit stop, and continuous turn handoff; no microphone starts automatically on an ordinary launch.
- Island links and activation shortcut from cold/warm launches, devices without Dynamic Island, activity ending under system control, and no stale/cross-account snippets after sign-out.
- Time reminders at the selected local time, ambiguous/past times rejected, arrival reminders at a uniquely named saved address, duplicate place names rejected, context check consumes the matching reminders, and deletion cancels notification delivery.
- Briefing source denial/failure clearly distinguished from an empty calendar/inbox; Gmail callback state/PKCE and Keychain persistence/refresh/sign-out account isolation; WeatherKit attribution and unavailable capability.
- Notes/settings/conversation persistence after restart; account A → account B → demo cannot reveal A's memories/messages; a stopped response cannot append later or execute further tools.
- Dynamic Type, reduced motion/transparency, light/dark appearance, keyboard layout, and real latency measurements.

This is implementation for review, not a verified production launch. Real integration/device evidence is still required.
