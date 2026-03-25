# VC PoC - iOS Voice Rooms

SwiftUI iOS app for voice chat rooms using Supabase (auth + room metadata) and LiveKit Cloud (audio transport).

## Required external software/services

- LiveKit Cloud project
- Supabase project (Auth, Postgres, Edge Functions)
- Apple Developer account (for TestFlight distribution)
- Optional: Sentry project for crash reporting

## Local configuration

Set these run-scheme environment variables in Xcode:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `LIVEKIT_URL` (for example `wss://your-project.livekit.cloud`)
- `LIVEKIT_TOKEN_FUNCTION_URL` (Supabase edge function endpoint)

When these are missing, the app shows a setup-required screen and blocks room access.

## iOS permissions/capabilities

- Microphone usage description is required.
- Enable Background Modes -> Audio if room audio should continue in background.

## Supabase setup

1. Apply all SQL migrations in `supabase/migrations/` (including the room policy recursion fix).
2. Configure function auth behavior in `supabase/config.toml` (this project disables gateway JWT verification and validates JWTs inside each function).
3. Deploy edge functions in:
   - `supabase/functions/livekit-token`
   - `supabase/functions/join-room`
4. Configure edge function secrets:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `LIVEKIT_API_KEY`
   - `LIVEKIT_API_SECRET`
   - `LIVEKIT_URL`
5. Set Xcode run-scheme `LIVEKIT_TOKEN_FUNCTION_URL` to your function invoke URL:
   - `https://<your-project-ref>.supabase.co/functions/v1/livekit-token`
