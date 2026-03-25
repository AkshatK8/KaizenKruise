# TestFlight Rollout

## Build prerequisites

- Set run/build secrets:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `LIVEKIT_URL`
  - `LIVEKIT_TOKEN_FUNCTION_URL`
- Enable microphone usage description and background audio mode.
- Confirm Supabase migration and edge functions are deployed.

## Release process

1. Archive app in Xcode.
2. Upload archive to App Store Connect.
3. Create TestFlight group:
   - Internal team
   - External beta testers (optional)
4. Add release notes with:
   - Supported devices
   - Known limitations
   - Test scenarios from `docs/QA_CHECKLIST.md`

## Post-release monitoring

- Watch crash-free sessions (Sentry or App Store metrics).
- Monitor Supabase function logs for auth and token errors.
- Track LiveKit usage and participant-minute spend.
