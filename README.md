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

1. Install [Flutter](https://docs.flutter.dev/get-started/install).
2. Create accounts: [Supabase](https://supabase.com), [Google AI
   Studio](https://aistudio.google.com) (Gemini key), [RevenueCat](https://www.revenuecat.com),
   Google Cloud Console (OAuth client for Google Sign-In).
3. Run every file in `supabase/migrations/` in order, in your Supabase
   project's SQL editor.
4. Deploy the edge functions:
   ```
   supabase login
   supabase link --project-ref your-project-ref
   supabase functions deploy mom-chat delete-account revenuecat-webhook send-nudges
   supabase secrets set GEMINI_API_KEY=your-key       # optional, see .env.example
   supabase secrets set REVENUECAT_WEBHOOK_SECRET=make-up-a-random-value
   ```
   Add that same webhook secret in RevenueCat → Webhooks.
5. Copy `config/local.json.example` to `config/local.json` and fill in
   your keys (`.env.example` lists where each one comes from). Never
   commit this file — it's gitignored.
6. Run:
   ```
   flutter run --dart-define-from-file=config/local.json
   ```

## Not implemented yet

- **Stripe** — not used. Apple/Google require in-app purchases to go
  through their own payment systems, not a separate processor.
- **Sign in with Apple** — code exists, fails gracefully, but needs a
  paid Apple Developer account to configure/test.
- **Real subscription purchases** — RevenueCat is wired up, but needs
  paid App Store Connect / Play Console products to actually buy.
- **Metric/imperial toggle** — not functional yet.

Everything else is built and wired to the real backend.
