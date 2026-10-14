# Max Supabase setup

Verified on October 14, 2026 for the native iPhone V1.

## Connected project

- Organization: **Max.ai** (Free plan).
- Project: **GindausD2's Project**, reference `omcboajliacdnhrroijb`, region `us-east-2`.
- API URL: `https://omcboajliacdnhrroijb.supabase.co`.
- The previously paused project was resumed and confirmed `ACTIVE_HEALTHY` before the final migrations were installed and verified.
- Use the active modern publishable key in `ios-swift/Configuration/Public.supabase.example.xcconfig`. It is intentionally public. Provider keys, database passwords, secret keys and service-role keys do not belong in the app.

## Database installed and verified

Hosted migration history contains:

1. `20261014111015_max_v1_usage_limits` — the existing `backend/sql/001_usage.sql` source: `public.max_usage` and `public.consume_max_request()`.
2. `20261014111307_max_restrict_rls_trigger_api` — removes API execution rights from the pre-existing automatic RLS event-trigger helper while preserving the trigger:

```sql
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
```

The usage function permits 20 generation requests per minute and 100 per UTC day per authenticated account. Continuation requests also count. Its security-definer implementation uses an empty search path, explicitly qualified objects and `auth.uid()`; clients cannot supply another user's ID or reset counters.

Verification on the hosted database confirmed:

- RLS enabled; direct reads/writes denied by grants to `anon` and `authenticated`.
- Anonymous execution denied; authenticated execution granted.
- Runtime minute/day boundaries, separate counters for two injected identities, and rejection without an identity. These tests invoked the real function with SQL-injected claims in a transaction, then rolled back the temporary account/counter fixtures. They do not establish a real Apple login or HTTP bearer-token flow.
- Zero persisted account and usage rows after fixture rollback.
- Automatic RLS still runs on new public tables after the helper's API privileges were revoked; its verification table was rolled back.
- Auth settings endpoint returns HTTP 200 using the publishable key. Apple is **disabled**; anonymous sign-in is **disabled**.

Security advisors retain two intentional notices: [RLS without a policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), because clients must not access the counters directly, and [authenticated security-definer execution](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), because this constrained authenticated RPC must update the inaccessible counters. Do not grant direct table access to silence these notices. The former public execution warning on `rls_auto_enable()` was fixed.

## Native configuration

On the Mac used to build Max:

```sh
cd ios-swift
cp Configuration/Public.supabase.example.xcconfig Configuration/Public.xcconfig
```

This project's URL and public key are already populated. Set `DEVELOPMENT_TEAM` for your Apple Developer team and `MAX_API_BASE_URL` once the backend is deployed. `Public.xcconfig` is ignored by Git. The workspace copy has been prepared; committed source contains the reusable public template.

For the backend, set `SUPABASE_URL` to the API URL above and `SUPABASE_ANON_KEY` to the same publishable key. The variable retains its compatibility name but accepts the modern publishable key. No service-role key is needed. Provider/backend deployment remains separate; the current backend still uses Anthropic and must be migrated to OpenAI before an OpenAI key can power Max.

## Apple sign-in still needs dashboard and signing setup

The connected Supabase tools expose database/project operations but not Auth-provider configuration. No Apple-provider changes were made.

1. Open [this project's Authentication providers](https://supabase.com/dashboard/project/omcboajliacdnhrroijb/auth/providers), select Apple, enable it, and add `com.gindausd.max` under Client IDs. Save.
2. In your [Apple Developer identifiers](https://developer.apple.com/account/resources/identifiers/list), register or select the matching App ID, enable **Sign in with Apple**, and regenerate the provisioning profile used to sign Max.
3. The app uses native Apple Authentication Services and exchanges the identity token with Supabase. Native-only Apple sign-in does not require the web OAuth Services ID, client secret or `.p8` setup. See [Supabase's native Swift configuration](https://supabase.com/docs/guides/auth/social-login/auth-apple?platform=swift).
4. Build a signed app and test first sign-in, returning sign-in, cancelled sign-in, session restoration and sign-out on an iPhone. Then test the backend with that real session.

Real Apple sign-in, authenticated HTTP quota calls, OpenAI responses, backend hosting and physical-device features remain unverified. Memory and conversation content remain account-scoped local storage; this setup does not add cloud memory sync.
