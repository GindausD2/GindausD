# Max V1 — The AI Companion

Release focus: the native iPhone app, with Dynamic Island as its identity. The Expo app remains the design preview; Expo and native Android are not yet equivalent release clients for these native V1 changes.

The native V1 beta is available after sign-in without a mandatory StoreKit purchase gate. Existing subscription code is retained but the purchase entry point is hidden from V1 Settings; server usage limits control AI generation.

Keep the premium glacier-blue glass design. Priorities are speed, personality, a useful daily ritual, and memory the user controls. Booking rides/flights, purchases, and advanced autonomous agents are excluded.

The glass orb is an explicit speech control: tap to hear Max's greeting or replay the latest completed reply, and tap again to stop. Use the separate microphone to talk. While speaking, its rings pulse and waveform moves; reduced-motion settings keep it still. Native speech-word callbacks request soft, throttled iPhone haptics while the app is active. The optional Speaking haptics preference disables these pulses, including on older saved settings. Speech and haptics stop when the conversation ends or the app leaves the foreground. The Expo web app previews this appearance and tap/stop interaction; browser audio and iPhone haptic delivery still need real-device acceptance testing.

| Area | Implemented in source | Verification / remaining setup |
| --- | --- | --- |
| Voice | Native microphone/speech permissions, partial speech recognition, native spoken replies, voice selection, optional silence-ended continuous conversation while app is open, explicit stop and cancellation | Xcode simulator and unsigned iPhone Release builds have passed. Microphone, recognition, audio interruptions, and continuous handoff still require physical-device testing. On-device recognition is preferred; Apple recognition may use its servers when unavailable locally. Not an always-listening background assistant. |
| Dynamic Island | Compact/expanded Live Activity views, glacier-blue accents, Talk / Briefing / Plan links opening Max, activation shortcut, lock-screen fallback | Both extensions compile in simulator and unsigned iPhone builds. Signing and physical-device interaction remain unverified. The system controls activity lifetime; this is not a permanent overlay across arbitrary apps. |
| Morning briefing | Scheduled local notification; on tap, builds a calendar / saved-place weather / pending-reminder snapshot; adds unread-important Gmail count when connected; local spoken fallback without AI | Not a system alarm or automatic background voice wake-up. WeatherKit capability and Gmail OAuth configuration are needed. Missed-call history is not supplied. Remote live pushes while closed are not configured. |
| Reminders | Future time validation, OS local notifications, arrival trigger at a manually saved place, context reminders surfaced when explicitly checked, manual creation/deletion; successful saves show the confirmed date/time and time zone, saved arrival place/address, or explicit context | Geofencing accuracy/delivery and notification permissions require device testing. Signing out/account switching cancels old scheduled notifications and clears widget text; saved records remain account-scoped, but cancelled time/arrival reminders need scheduling again. Context reminders do not monitor behavior in other apps. |
| Memory | Local notes, explicit facts/cards, manually saved addresses, conversation archive/timeline, per-account local storage scopes; edit and forget saved notes/facts/cards in Your day or Memory | Native simulator regressions cover memory isolation/restoration, older settings/place decoding, context reminders, invalid times, ambiguous places, V1 exclusions, stopped replies, and stale account tool calls; see verification evidence below. Real account sign-in/sign-out and device tests still needed. Legacy unscoped data stays in local demo only. Navigation searches must not be represented as confirmed visits. |
| Managed AI | Native calls `/v1/messages` with an authenticated Supabase session; provider key stays on server; bounded native tool loop; standard tool-use/result protocol; cancellation; V1 allowlist; database-enforced usage quota | 17 server tests pass, including the real HTTP adapter, split-Unicode streaming, validation, and disconnect cancellation with stubbed auth/provider responses. Disposable PostgreSQL 16 checks pass for concurrent minute caps, daily caps, account separation, and denied table/anonymous access. Live backend deployment, production SQL migration, authentication config, and real provider streaming remain unverified. |
| UI | Glacier-blue assistant control, warm glass surfaces, text input, Your day hub, Settings without API/client-ID entry, reduced-motion/transparency support | Expo builds were verified previously. Native compilation is verified; Liquid Glass/layout/accessibility/device interactions still need visual/device acceptance testing. |

## Configure the native release

1. Use Xcode 26 on a Mac. Copy `ios-swift/Configuration/Public.example.xcconfig` to `Public.xcconfig` and set the public backend URL, Supabase URL/publishable key, signing team, and optional iOS Google OAuth client ID. Never add an Anthropic key to this file.
2. Install XcodeGen from its official source, run `xcodegen generate` in `ios-swift`, and open `Max.xcodeproj`. The spec supplies the app and two widget extension targets, shared attributes/logo source membership, app-group entitlements, Speech privacy text, URL schemes, Supabase dependency, and WeatherKit capability.
3. Configure Apple signing, App Group `group.com.gindausd.max`, Sign in with Apple, and WeatherKit for the app and relevant extensions. WeatherKit attribution is linked in the saved-places hub; verify required attribution presentation before distribution.
4. If enabling Gmail, configure the iOS Google OAuth client for bundle `com.gindausd.max` and custom callback `com.gindausd.max:/oauth2callback`, Gmail read-only scope, and authorized beta accounts/consent settings. The customer only taps Connect Gmail. Tokens are scoped by Max account and stored in Keychain; the authorization flow uses state and PKCE.
5. Generate/sign/build the project and complete the device checks below. GitHub Actions now runs XcodeGen, an unsigned app/extension simulator build, and native regression tests on a Mac runner. Use the completed run result below; syntax parsing alone is not native build verification.

## Configure the backend

1. In the same Supabase project as native sign-in, apply `backend/sql/001_usage.sql`. The RPC derives the user from `auth.uid()` and enforces 20 generation requests per minute and 100 per UTC day. Each continuation request counts. Clean older usage buckets on the database's maintenance schedule.
2. Set server-only `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` (optional), `SUPABASE_URL`, and `SUPABASE_ANON_KEY`. The anon/publishable key identifies the Supabase project; the customer's bearer token authenticates requests. A service-role key is not needed.
3. Run `npm start` from `backend` on Node 22+ and expose it behind HTTPS. No CORS/browser session integration is provided: this backend currently targets the native iPhone client.
4. Check `/health`, then verify real sign-in → authenticated `/v1/messages` → quota RPC → provider SSE → native text → spoken reply. Missing server configuration or quota installation fails closed.

## Verification evidence

The [Verify Max V1 workflow](https://github.com/GindausD2/GindausD/actions/workflows/verify.yml) records the source commit, full logs, and build/test artifacts. Check the latest completed run for the current PR commit.

- Node 22: 17 passing server tests, including real HTTP transport with stubbed authentication/provider responses.
- PostgreSQL 16 in a disposable CI database: 40 concurrent requests accept exactly 20; daily limits, account counters, anonymous denial, and denied direct table access pass. The auth schema/session identity is a test fixture, not a real Supabase login.
- Expo: TypeScript check passes.
- Xcode 26.2: simulator Debug and unsigned iPhone Release builds pass for Max and both extensions; the native regression suite runs on the iPhone simulator.
- Packaged-app checks validate privacy strings, Live Activity support, deep-link/OAuth schemes, background registration, compiled launch screen, expanded public configuration, and both extensions. Generation checks preserve the source Info.plist and App Group / Apple sign-in / WeatherKit entitlement files. Real signed entitlements still require Apple provisioning.

These checks do not exercise a real provider, production Supabase authentication, Google OAuth, WeatherKit signing, microphone input, location-trigger delivery, or physical Dynamic Island interaction. Local backend environment and native public release settings are absent. Hosting inspection returned HTTP 403 for the project scope, so the live server configuration was not inspected.

## Device acceptance checks

- Orb tap starts spoken greeting/replay without opening the microphone; second tap stops speech and haptics. Verify pulses during speech, the Speaking haptics switch, reduced motion, and background/interruption cleanup on a real iPhone.
- First microphone/speech permission, denied permission, speech unavailable, interrupted recording, backgrounding, explicit stop, and continuous turn handoff; no microphone starts automatically on an ordinary launch.
- Island links and activation shortcut from cold/warm launches, devices without Dynamic Island, activity ending under system control, and no stale/cross-account snippets after sign-out.
- Time reminders at the selected local time, ambiguous/past times rejected, arrival reminders at a uniquely named saved address, duplicate place names rejected, context check consumes the matching reminders, and deletion cancels notification delivery.
- Briefing source denial/failure clearly distinguished from an empty calendar/inbox; Gmail callback state/PKCE and Keychain persistence/refresh/sign-out account isolation; WeatherKit attribution and unavailable capability.
- Notes/settings/conversation persistence after restart; account A → account B → demo cannot reveal A's memories/messages; a stopped response cannot append later or execute further tools.
- Dynamic Type, reduced motion/transparency, light/dark appearance, keyboard layout, and real latency measurements.

This is implementation for review, not a verified production launch. Real integration/device evidence is still required.

## Memory controls and reminder confirmations

- In Your day → Notes, use the pencil to edit a note or remembered fact. Personal memory cards are also available from this screen and Settings → Memory. Each editor can forget the selected saved item. Memory changes affect context supplied for future messages; earlier conversation history remains separately managed.
- Editors capture the account they were opened for. Saves and forget actions reject an account change or a deleted item instead of recreating it or writing to a different account. Card updates preserve the existing ID/creation date and read fresh storage rather than replacing a stale list snapshot.
- A successful reminder form stays open on a confirmation showing the stored reminder and its real trigger. Time reminders include the local date/time/time zone; arrival reminders use the saved name/address; context reminders explicitly say they appear when that context is checked in Max. The tool response and Live Activity also use confirmed trigger details.
- Native regression coverage includes scoped edit/forget, deleted-item protection, stored identity preservation, local-date formatting across midnight, and reminder result IDs. Real device notification delivery and integration setup still require the acceptance checks above.

## Microphone voice-to-text

The home composer microphone opens a glacier-blue Liquid Glass capture panel with live partial words. Done finishes recognition and appends the result to the existing editable message draft. Nothing is sent until the user selects Send; these voice drafts request text replies without automatic speech or continuous listening. Cancel/backgrounding discards the unfinished capture while preserving the original draft. Permission failures and empty recognition show a recoverable message without creating a conversation entry. Account changes invalidate pending recognition. The orb remains an explicit speech/replay control; the existing Talk shortcut still enters the separate conversation flow.

The panel uses the native iOS 26 glass material and the existing earlier-iOS material / reduced-transparency fallback. Its listening symbol respects reduced motion. Simulator tests use an injected capture fixture to check partial text, draft preservation, no automatic send, interruption, denied permission, cancellation and account isolation. Native captures use sample words; actual microphone accuracy and interruption handling still require physical-device acceptance testing.

## Reference-inspired home layout

The native home uses one glossy glacier-blue orb, a compact Max heading, generous spacing, and separate floating glass buttons. The orb has soft highlights and refraction rather than concentric outlined rings; its waveform appears while listening/speaking. New conversation and Settings sit at the top. Your day, Hear Max, History and Briefing remain reachable below the independent message field. Opening Settings, Your day or History ends foreground capture/playback. Voice-to-text still creates an editable draft and waits for Send.

The dock uses a bottom safe-area inset instead of a fixed overlay, so the transcript area follows the controls and keyboard. The light background stays quiet and warm; dark appearance has its own neutral background. Interactive glass controls use the native iOS 26 material, with the existing earlier-iOS and reduced-transparency fallback. Orb/dock motion respects reduced motion. Native screenshot fixtures cover idle home, dark home, listening and a finished voice draft using sample words. Physical-device layout, keyboard and audio acceptance remain required.
