# Max beta service — 21 October 2026

The new backend is deployed as a separate `max-api-beta` Supabase Edge Function.
The existing `max-api` function remains at version 15.

Base URL:
https://omcboajliacdnhrroijb.supabase.co/functions/v1/max-api-beta

Health:
https://omcboajliacdnhrroijb.supabase.co/functions/v1/max-api-beta/health

## Verified live

- Beta deployment version 1 starts successfully (HTTP 200).
- OpenAI and Supabase public connection settings are present.
- Text and voice requests without a token return HTTP 401.
- An invalid sign-in token returns HTTP 401 before generation.
- Existing service health remains HTTP 200.
- Beta billing is **not configured**. This endpoint is fixed to Apple's Sandbox
  environment and uses separate `MAX_BETA_APPLE_*` server secrets.
- Anonymous sign-in is still **disabled**; Apple provider is enabled.
  Manual identity linking remains unverified.

These checks do not prove a successful OpenAI conversation, real voice generation,
Apple sign-in, a purchase or a signed iPhone install. No test user was created.

## Next setup

1. In the project's Authentication → Sign In / Providers page, enable anonymous
   sign-ins and manual identity linking. The connected Supabase tools do not
   expose these settings, and the local CLI has no management access token.
   Dashboard: https://supabase.com/dashboard/project/omcboajliacdnhrroijb/auth/providers
2. Test one real guest → beta text response → beta voice request. Confirm the
   same account's seven-day clock and quotas. The OpenAI key stays on the server.
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
its deployed service passed the live checks above.

Native build: https://github.com/GindausD2/GindausD/actions/runs/39632669846
