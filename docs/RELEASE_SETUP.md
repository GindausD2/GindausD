# Max AI release update — 21 October 2026

This package contains source changes, not a signed app or a production launch.
The source is uploaded to GitHub PR #2. The current native build/test status is
tracked by GitHub Actions; the Edge Function update has not been deployed.
https://github.com/GindausD2/GindausD/pull/2

## Price chosen by the owner

- Launch monthly subscription: **US $4.99**.
- App Store product: `com.gindausd.max.pro.monthly`, auto-renewable, one month.
- Annual pricing is undecided; the annual plan is not offered by this build.
- Configure the price in App Store Connect. Every purchase screen uses Apple's
  actual localized `displayPrice`; there are no invented fallback prices.
- AI allowance: 100 managed requests per UTC day, 20 per minute; tool
  continuations count as requests. OpenAI voice allowance: 3,000 submitted text
  characters per UTC day, at most 2 playback requests per minute and 1,000 UTF-16
  units per request. Failed cloud attempts also reserve allowance. These are
  initial cost controls, not a verified profitability forecast for $4.99.

## Changes included

- Supplied logo alone replaces the text heading on Home and entry screens.
- Updated Login, Sign Up and seven-day Demo designs are included.
- Apple sign-in now creates a secure random nonce, hashes it for the Apple
  request, and supplies the original nonce to Supabase for sign-in or linking.
  Login can explicitly enter an existing account; signup/demo continuation links
  the guest. Accounts are never silently merged.
- OpenAI Marin/Cedar playback uses a bounded server-side Realtime request.
  The text/tool assistant is unchanged. Voice has no tools and cannot perform
  actions. The returned speech transcript must match the requested words;
  otherwise playback falls back to the iPhone voice.
- Explicit cancellation, account/background/interruption cleanup, optional
  speaking haptics, and a visible AI voice disclosure. Longer replies use the
  iPhone voice. This buffers a short WAV before playback; it is not a full duplex
  speech-to-speech Realtime conversation or an always-listening assistant.
- New purchases bind `appAccountToken` to the Supabase account UUID.
  The backend verifies Apple's signed transaction, checks current subscription
  status with Apple's server, and requires the same Max account, bundle,
  supported product and future expiry. Missing credentials fail closed.
- Text and cloud voice both enforce paid access for permanent accounts.
  Unexpired anonymous guests remain eligible without Apple sign-in or payment.
- Subscription restore/management and the Settings purchase page share honest
  pricing and supported benefits. Claims about unlimited conversations,
  priority responses, iCloud sync and custom wake phrases have been removed.
- A Mac archive/export script is supplied at
  `ios-swift/scripts/archive-beta.sh`. It creates an IPA for review and does
  not upload or publish it.

## Confirmed live state

Checked 21 October 2026:

- Supabase project is healthy; Apple provider is enabled.
- **Anonymous guest sign-in is disabled**, which blocks Try Demo.
- Manual identity linking could not be confirmed from the public Auth settings.
- The existing text quota function is installed.
- The new voice quota migration is installed. Live checks reject missing
  identity, null/negative inputs and public access to the private schema.
- Advisor results are unchanged: usage-table RLS has no direct policies because
  clients are intentionally denied table access, and the older text quota RPC
  is flagged for its authenticated SECURITY DEFINER execution. The new voice
  RPC uses an invoker wrapper and a private, identity-scoped definer function.

## Configuration still required

1. In Supabase Auth, enable anonymous sign-in and manual identity linking.
   Do not disable Apple token or nonce verification. Test guest → Apple linking
   with the same UUID and preserved local memories. An Apple identity already
   owned by another account needs explicit account recovery, not a silent merge.
2. In App Store Connect, create/confirm the monthly product at $4.99, complete
   agreements/tax/banking and the app's required privacy/terms metadata.
   Supply the App Store app ID and an In-App Purchase API key to the server's
   secret store, never to the phone or this ZIP. See backend/.env.example.
3. Obtain Apple root certificates from
   https://www.apple.com/certificateauthority/ and configure a JSON array of
   base64 DER certificates in APPLE_ROOT_CERTIFICATES_BASE64. Configure
   APPLE_IAP_KEY_ID, APPLE_IAP_ISSUER_ID, APPLE_IAP_PRIVATE_KEY and APPLE_APP_ID.
   Production is the default environment. Use a **separate Sandbox backend**
   for TestFlight purchase tests; production must not accept Sandbox receipts.
   Legacy purchases without the correct account token are not automatically
   assigned to a new account.
4. Verify OpenAI project access/billing for `gpt-realtime-2.1-mini` and the
   existing text model. The previously deployed backend does not yet have the
   new voice or subscription endpoints. Deploy these changes only after Apple
   configuration is ready; otherwise permanent accounts will fail closed.
5. Configure the Apple team, App Group, Sign in with Apple and WeatherKit
   entitlements. Gmail still needs an iOS Google OAuth client/consent setup.
   Public.xcconfig must contain public project/backend configuration only.
6. On a Mac with Xcode 26 and XcodeGen, run the existing simulator tests/builds.
   For a signed archive, export MAX_APPLE_TEAM_ID in the shell and run
   `bash ios-swift/scripts/archive-beta.sh`. Review the resulting IPA before
   TestFlight upload. Signing and delivery are not completed by this package.

## Acceptance before launch

- Real guest → text reply → spoken reply; exact seven-day expiry; guest → Apple
  account linking retains data. Real permanent account without a subscription
  cannot use the managed AI endpoints.
- Sandbox purchase and restore, account A/B isolation, cancellation, expiry,
  refund/revocation, interrupted verification and unavailable products.
- On a real iPhone: microphone allow/deny, editable voice draft, continuous
  handoff, speaker/Bluetooth/headphone interruptions, tap-to-stop while cloud
  audio loads or plays, haptics off/on and no playback after leaving the app.
- Real time/arrival notifications, saved-place WeatherKit results, calendar
  denial, Gmail OAuth/refresh/sign-out, Dynamic Island compact/expanded links
  on a supported phone, and fallback on phones without Dynamic Island.
- Light/dark, large text, reduced motion/transparency, keyboard, memory
  persistence and account isolation. Capture new native screenshots.

## Verification of this update

- 42 Node backend tests passed using fixture authentication/provider responses.
- Deno Edge Function entry type-check passed with installed locked dependencies.
- One Deno transport test passed using a real localhost WebSocket and fixture
  auth/provider data; it verifies WAV delivery in the Edge runtime, not OpenAI.
- Embedded PostgreSQL checks passed for voice caps, invalid sizes, account
  separation and denied direct access. Live installed-function checks passed.
- The GitHub backend job passed for commit 9c460d04e8bd266556a16fbbc9977438a22ac279,
  including the real PostgreSQL concurrent minute/character caps and account
  isolation checks.
- The first Xcode build exposed optional account fields in StoreKitService.
  Those are corrected in the follow-up source update. Check the latest Actions
  run for compilation/tests; a syntax parser alone does not verify an iOS build.
- The archive script passes shell syntax validation; no signed archive exists.
- No production OpenAI voice, Apple purchase, Gmail, WeatherKit, physical-device
  acceptance or fresh native screenshot is claimed.

Official implementation references:
https://developers.openai.com/api/docs/guides/realtime-conversations
https://developers.openai.com/api/docs/guides/realtime-websocket
https://github.com/apple/app-store-server-library-node
https://supabase.com/docs/guides/auth/auth-anonymous
