# Max AI V1 App Review handoff

Use the same signed build, live review backend, metadata and screenshots that will go to App Review.

| Video item | Release evidence to collect |
| --- | --- |
| Digital payments | Max Pro uses Apple StoreKit. Review the monthly price and duration, renewal terms, Privacy Policy, Terms of Use, and access after a verified purchase. |
| Sign in with Apple | Test the welcome entry and guest-to-Apple upgrade on a signed device. |
| Delete Account | Confirm deletion from Settings, the subscription screen, and the expired demo screen. Test with a disposable account. Verify Supabase removal, Apple authorization revocation for a permanent account, and local data removal. |
| Native app | Review the signed SwiftUI application and its native voice, memory and reminder experiences. |
| Demo access | On a clean installation, select Try Demo and send a real request. Enable anonymous auth and keep the review backend reachable. Provide App Review full access through review credentials or confirm use of the built-in demo with Apple. Include exact access steps in Review Notes. |
| iPad layout | Check welcome, demo, chat, keyboard, settings and subscription in portrait, landscape, split view and accessibility text sizes on iPad. The tablet-sized capture is only a layout fixture. |
| Current screenshots | Capture the submitted build on the required simulator or device sizes. Replace stale images in App Store Connect. |
| Placeholder screens | Keep unavailable integrations out of the release navigation. Check every remaining entry point with release configuration. |
| Links | Open support, the app-specific Privacy Policy, Terms of Use and Manage Apple Subscriptions. Confirm the support mailbox receives a test message. |
| Reporting | In the chat plus menu, choose Report a response, verify the email and the copyable address, and verify support receives a user-sent report. Max does not attach the conversation automatically. |
| Restore Purchases | Test valid, missing, expired and wrong-account purchases using the separate Apple Sandbox backend. Verify the result appears and access only unlocks for a verified entitlement. |
| Paid-feature screenshots | Capture actual in-app screens and identify paid-only functionality clearly in the App Store listing. |

## Server and App Store Connect setup

- Account deletion uses the existing Max API host. Deploy this API separately after verifying it against a staging account. Configure `SUPABASE_SERVICE_ROLE_KEY`, `MAX_APPLE_SIGN_IN_CLIENT_ID` (the native Sign in with Apple client identifier), and `MAX_APPLE_SIGN_IN_CLIENT_SECRET` (the Apple Sign in with Apple client-secret JWT). Rotate the JWT before it expires. Keep these server-side. The App Store purchase key is separate.
- Set `MAX_PRIVACY_POLICY_URL` in the release build configuration to the public, app-specific HTTPS policy. Set the same policy in App Store Connect. Review the policy against the final data handling and account-deletion behavior before submission.
- Confirm the monthly product in App Store Connect and attach it to the submission. Include the product and restore locations in Review Notes.
- Upload fresh iPhone and iPad screenshots as required for the signed build, add paid-feature disclosures, and complete the review notes and metadata before submitting.

Reference: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) and [Sign in with Apple account deletion](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple).
