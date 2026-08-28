# AI Mom

A mobile app where an AI "Mom" checks in on you, tracks your tasks,
habits, spending, and health, and nags or encourages you in character.

Built with Flutter (one codebase for iPhone and Android), Supabase
(database + login), Google Gemini (Mom's chat brain), and RevenueCat
(subscriptions).

## Quick start

1. **Install Flutter:** https://docs.flutter.dev/get-started/install
2. **Create accounts** (free to start): [Supabase](https://supabase.com),
   [Google AI Studio](https://aistudio.google.com) (for a Gemini API
   key), [RevenueCat](https://www.revenuecat.com), and a Google Cloud
   Console OAuth "Web" client (for Google Sign-In).
3. **Set up the database** — in your Supabase project's SQL editor, run
   every file in `supabase/migrations/` in order (0001, 0002, …).
4. **Deploy the edge functions** — install the [Supabase
   CLI](https://github.com/supabase/cli#install-the-cli) (`npm install
   -g supabase` doesn't work, Supabase blocks it — use `scoop`/`brew`/a
   direct download instead), then:
   ```
   supabase login
   supabase link --project-ref your-project-ref
   supabase functions deploy mom-chat delete-account revenuecat-webhook send-nudges
   supabase secrets set GEMINI_API_KEY=your-key-here          # optional — see note below
   supabase secrets set REVENUECAT_WEBHOOK_SECRET=make-up-a-long-random-value
   ```
   Then add that same webhook secret in RevenueCat's dashboard (Project
   settings → Webhooks), pointing at your `revenuecat-webhook` function
   URL. `GEMINI_API_KEY` is optional for testing — without it, chat
   still works end-to-end (auth, saving messages, the weekly limit) and
   just replies with an obvious placeholder instead of a real AI reply.
5. **Give the app its keys:**
   ```
   cp config/local.json.example config/local.json
   ```
   Fill in the values from your accounts above (`.env.example` explains
   where each one comes from). This file is gitignored — it never gets
   committed.
6. **Run it:**
   ```
   flutter run --dart-define-from-file=config/local.json
   ```
   Skip step 5 and the app still opens, just with a "missing
   configuration" screen instead of crashing.

**Push notifications (Firebase) are optional** — the app works fully
without them, Mom just can't nudge you when the app isn't open. See the
comments in `.env.example` and `supabase/migrations/0009_nudge_scheduling.sql`
if you want to wire it up later.

## Not implemented yet

- **Stripe payments** — intentionally not used. Apple and Google
  require in-app subscriptions to go through their own payment systems
  (StoreKit / Play Billing), not a separate processor like Stripe, so
  RevenueCat wraps those instead.
- **Sign in with Apple** — the code path exists
  (`AuthService.signInWithApple`) and fails with a clear in-app message
  rather than crashing, but actually configuring and testing it needs a
  paid Apple Developer Program membership ($99/year), which isn't set
  up. Email and Google sign-in work today.
- **Real subscription purchases** — RevenueCat is fully wired up, but
  there's nothing to actually *buy* yet: that needs App Store Connect /
  Google Play Console products configured, which needs paid developer
  accounts on both platforms.
- **Metric/imperial unit toggle** — the Settings row for it isn't
  functional; nothing in the app currently displays a unit-dependent
  value (weight, distance) for it to affect.

Everything else — tasks/habits, chat, financial and health tracking,
account settings, plan gating, on-device reminders, Mom's proactive
push nudges (once Firebase is configured) — is built and wired to the
real backend, not mocked.
