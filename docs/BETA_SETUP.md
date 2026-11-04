# Max beta service — updated 22 October 2026

The new backend is deployed as a separate `max-api-beta` Supabase Edge Function.
The existing `max-api` function remains at version 15.

Base URL:
https://omcboajliacdnhrroijb.supabase.co/functions/v1/max-api-beta

Health:
https://omcboajliacdnhrroijb.supabase.co/functions/v1/max-api-beta/health

## Verified live

- Beta deployment version 2 includes bounded, redacted provider diagnostics.
- OpenAI and Supabase public connection settings are present.
- Text and voice requests without a token return HTTP 401.
- An invalid sign-in token returns HTTP 401 before generation.
- Existing service health remains HTTP 200.
- Beta billing is **not configured**. This endpoint is fixed to Apple's Sandbox
  environment and uses separate `MAX_BETA_APPLE_*` server secrets.
- Anonymous sign-in and manual identity linking are **enabled**, saved and
  verified after a dashboard reload. The Apple provider remains enabled.
- Real anonymous sign-in returned HTTP 200. Two anonymous connection-test
  accounts were created on 22 October; they contain no personal content.
- A real guest text request reached OpenAI and returned HTTP 429 with the
  server-side diagnostic `credit_balance_exhausted`.
- A real guest voice request also reached OpenAI and returned the same
  `credit_balance_exhausted` provider code (the app-facing response was 502).
- Diagnostics record approved codes only, never provider messages, keys,
  bearer tokens or conversation text. Unknown codes are discarded.

These checks do not prove a successful OpenAI conversation, real voice generation,
Apple sign-in, a purchase or a signed iPhone install.

## Next setup

1. The owner must restore OpenAI API credits for the organization associated
   with the configured server key. Repeated requests cannot fix exhausted
   prepaid credits. No payment or billing-setting changes were performed.
2. After credits are restored, repeat one real guest → beta text response →
   beta voice request. Successful text and audio generation remain unverified.
   The seven-day trial and quota enforcement have fixture/concurrency coverage;
   a full seven-day live trial lifecycle has not been observed.
3. Create the monthly App Store product `com.gindausd.max.pro.monthly` at the
   owner's chosen US $4.99/month price. Configure the In-App Purchase API key,
   issuer/key IDs and Apple root certificates as the beta-prefixed server
   secrets listed in backend/.env.example. Do not paste private keys into chat.
4. For the signed test app, copy Public.beta.example.xcconfig to Public.xcconfig,
   enter the Apple signing team and configure App Group / Apple sign-in /
   WeatherKit provisioning. The included public template sets the beta URL.
5. Archive/export on a configured Mac, upload to TestFlight, and complete the
   physical-device checks in RELEASE_SETUP.md. A separate Production rollout
   still requires production billing configuration and explicit release review.

## Source and build evidence

The native app code in commit 05867400c7aa1846ae8824ad3ed4e2d3b74c2e05 passed
simulator and unsigned iPhone Release builds, bundle checks and 24 native tests.
The beta update adds server/configuration files; it does not change Swift app
source. Its Deno entry type-check and all 42 backend tests passed locally, and
its deployed service passed the live checks above. The 22 October diagnostic
update passed 45 backend tests and the beta Deno entry type-check locally.

Native build: https://github.com/GindausD2/GindausD/actions/runs/39632669846
