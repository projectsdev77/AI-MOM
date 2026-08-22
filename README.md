# AI Mom

A productivity and life-coaching app where your AI Mom checks in on you,
tracks tasks, habits, spending, and health, and nags or encourages you in
character. Flutter client, Supabase backend, Claude for chat, RevenueCat
for subscriptions.

## Stack

- **Client:** Flutter, Riverpod, go_router
- **Backend:** Supabase (Postgres + Auth + Edge Functions) — schema in
  `supabase/migrations/`, server logic in `supabase/functions/`
- **Chat:** Claude (Anthropic API), called from the `mom-chat` edge
  function so the API key never reaches the client
- **Subscriptions:** RevenueCat, wrapping Apple/Google IAP (not Stripe —
  in-app subscriptions consumed inside the app must go through
  StoreKit/Play Billing per store policy)

## Running locally

Nothing in this repo is configured with real secrets. You need:

1. A Supabase project — apply `supabase/migrations/*.sql` in order (via
   the SQL editor, or `supabase db push` if you have the CLI linked).
2. `ANTHROPIC_API_KEY` set as a secret on the `mom-chat` edge function.
3. A RevenueCat project with an entitlement called `full_mom`, and
   `REVENUECAT_WEBHOOK_SECRET` set as a secret on the
   `revenuecat-webhook` edge function (point RevenueCat's webhook at
   that function's URL with the same secret as its Authorization header).
4. A Google Cloud OAuth **Web** client ID for Google Sign-In (used as
   `serverClientId` so the ID token Supabase receives has the right
   audience), and Sign in with Apple configured for your bundle ID.

Deploy the edge functions with the Supabase CLI:

```
supabase functions deploy mom-chat delete-account revenuecat-webhook
supabase secrets set ANTHROPIC_API_KEY=... REVENUECAT_WEBHOOK_SECRET=...
```

Then run the app with those values as dart-defines. Easiest is a local,
gitignored file:

```json
// config/local.json  (already gitignored)
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "...",
  "REVENUECAT_IOS_KEY": "...",
  "REVENUECAT_ANDROID_KEY": "...",
  "GOOGLE_WEB_CLIENT_ID": "....apps.googleusercontent.com"
}
```

```
flutter run --dart-define-from-file=config/local.json
```

Without these, the app shows a "missing configuration" screen instead of
crashing (see `lib/core/config/`).

## What's real vs. still mocked

Wired to Supabase: auth (email/password, Google, Apple), onboarding
answers, the unified task/habit model with server-side streak tracking,
chat (via the `mom-chat` edge function, including the Basic-tier weekly
message cap enforced server-side), account deletion, and RevenueCat
entitlements driving the plan gate.

Still local-only / not built yet: adding a task from the UI (the FAB is
a no-op), expense/budget entry, health logging, scheduled push
notifications and the streak-decay cron (the SQL function exists in
`0002_streak_decay.sql` — it needs `pg_cron` scheduled once the project
is live), and the currency/units settings rows are display-only.
