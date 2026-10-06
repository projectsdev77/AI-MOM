# AI Mom

Mobile app (Flutter, iOS + Android) where an AI "Mom" tracks your tasks,
habits, spending, and health, and checks in on you in character.

## Tech stack

- **App:** Flutter/Dart
- **Backend:** Supabase (Postgres, auth, edge functions)
- **Chat:** Google Gemini
- **Subscriptions:** RevenueCat (wraps Apple/Google in-app purchases — no Stripe)
- **Push notifications:** Firebase Cloud Messaging (optional)

## Setup

The Supabase/RevenueCat/Google/Firebase projects already exist — use
the existing credentials (handed off separately), not new accounts.

1. Install [Flutter](https://docs.flutter.dev/get-started/install).
2. Copy `config/local.json.example` to `config/local.json` and fill in
   the existing project's keys (`.env.example` lists what each one is).
   Never commit this file — it's gitignored.
3. Run:
   ```
   flutter run --dart-define-from-file=config/local.json
   ```

Database migrations (`supabase/migrations/`) and edge functions
(`mom-chat`, `delete-account`, `revenuecat-webhook`, `send-nudges`) are
already deployed on the existing Supabase project. Only re-run them if
setting up against a different project:
```
supabase login
supabase link --project-ref your-project-ref
supabase functions deploy mom-chat delete-account revenuecat-webhook send-nudges
```

### RevenueCat webhook (required for paid plans to work)

The app learns about a purchase from RevenueCat directly, but the server only
knows what is in `profiles.plan` — and only this webhook updates it. Without it
a user who buys Full sees the Full screens but still hits the Basic limits
(5 tasks, weekly chat cap, no health/finance nudges).

1. Pick a long random secret and store it:
   `supabase secrets set REVENUECAT_WEBHOOK_SECRET=<secret>`
2. Deploy without the login-token check (RevenueCat can't send one; the
   function checks the secret itself):
   `supabase functions deploy revenuecat-webhook --no-verify-jwt`
3. RevenueCat > Project settings > Integrations > Webhooks > add a webhook:
   URL `https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook`,
   Authorization header `Bearer <secret>`, events for both Production and
   Sandbox.
4. Test: make a purchase, then check `profiles.plan` is `full`. Turning off
   auto-renew keeps Full until the paid period ends, then `EXPIRATION` sets it
   back to `basic`.

### Email verification (required for production)

Signing up with email and password asks for a 6-digit code before the
account is created. The app side is built; it switches on from these
Supabase dashboard settings (they are not in any migration):

1. **Authentication → Sign In / Providers → Email**: turn **Confirm email**
   on. While it is off, sign-up logs in immediately with no code.
2. **Authentication → Email Templates → Confirm signup**: the email must
   contain the code, so put `{{ .Token }}` in the body, for example:
   ```html
   <h2>Confirm your email</h2>
   <p>Your AI Mom code is:</p>
   <h1>{{ .Token }}</h1>
   <p>It expires in 1 hour. If you didn't sign up, ignore this email.</p>
   ```
   Leave out `{{ .ConfirmationURL }}`: tapping a link would confirm the
   account but not return to the app with the onboarding answers.
3. **Authentication → Emails → SMTP Settings**: set up a real SMTP provider
   (Resend, SendGrid, Postmark, etc.). Supabase's built-in email sender is
   for testing only and allows just a few emails an hour, so real sign-ups
   would fail with "email rate limit exceeded".

Supabase allows one email per address per minute, so the app's "Resend
code" button waits 60 seconds. Google sign-in needs none of this: Google
has already verified the address.

## Not implemented yet

- **Stripe** — not used. Apple/Google require in-app purchases to go
  through their own payment systems, not a separate processor.
- **Sign in with Apple** — code exists, fails gracefully, but needs a
  paid Apple Developer account to configure/test.
- **Real subscription purchases** — RevenueCat is wired up, but needs
  paid App Store Connect / Play Console products to actually buy.
- **Metric/imperial toggle** — not functional yet.

Everything else is built and wired to the real backend.
