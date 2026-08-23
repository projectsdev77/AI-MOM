# AI Mom

A mobile app where an AI "Mom" checks in on you, tracks your tasks,
habits, spending, and health, and nags or encourages you in character.

This README explains what the app is built with, what outside services
it needs, and how to get it running. Written in plain language on
purpose — no assumed background.

## What this app is built with

- **The app itself:** Flutter (one codebase for iPhone and Android)
- **The database and login system:** Supabase
- **Mom's chat brain:** Google Gemini (free tier, no credit card needed)
- **Subscriptions (paid plans):** RevenueCat, which handles Apple and
  Google's in-app purchase systems for us

## Outside services this app depends on

None of these are optional — the app needs all of them to fully work.
Here's what each one does, in plain terms:

| Service | What it's for | Costs money? |
|---|---|---|
| [Supabase](https://supabase.com) | Stores all the data (users, tasks, chats, spending, health) and handles login | Free to start |
| [Google AI Studio](https://aistudio.google.com) | Powers Mom's chat replies (Gemini API) | Free — no credit card required |
| [RevenueCat](https://www.revenuecat.com) | Manages the Basic/Full subscription plans | Free to start |
| Google Cloud Console | Lets people sign in with Google | Free |
| Apple Developer Program | Lets people sign in with Apple, and is required to publish on the App Store either way | $99/year |

We are **not** using Stripe for payments — Apple and Google require
in-app subscriptions to go through their own payment systems, not a
separate card processor like Stripe.

## A note on accounts and keys

I (the AI assistant) can't create these accounts for you. Signing up
needs your own email, and some need a credit card or business details —
that's not something I can or should do on your behalf. I also won't
paste real passwords or API keys into our chat, even if I had them,
since chat messages aren't a safe place to store secrets.

What I've done instead: every part of the app that needs a secret reads
it from a file that stays on your computer and is never uploaded to
GitHub (see "Setup" below). You create the accounts, copy a few codes
into that file, and everything connects.

## Setup — step by step

### 1. Install Flutter

Follow Google's guide: https://docs.flutter.dev/get-started/install

### 2. Create your accounts

Go to each site below, sign up, and follow their basic "create a new
project" steps. You don't need to configure anything advanced yet.

1. **Supabase** — supabase.com → New Project
2. **Google AI Studio** — aistudio.google.com → sign in with any Google account → Get API key (no credit card needed)
3. **RevenueCat** — revenuecat.com → New Project
4. **Google Cloud Console** — console.cloud.google.com → create an
   OAuth "Web" client (needed even though this is a mobile app — it's
   used to verify the sign-in token)
5. **Apple Developer Program** — developer.apple.com (only needed when
   you're ready to test/publish on iPhone)

### 3. Set up the database

In your Supabase project, open the SQL editor and run the two files in
`supabase/migrations/` in order (0001 first, then 0002). This creates
all the tables the app needs.

### 4. Deploy the server-side code (edge functions)

These run on Supabase's servers, not on the phone — this is where the
Gemini key lives, so it's never exposed to the app itself.

First, install the Supabase command-line tool. Note: `npm install -g
supabase` does **not** work — Supabase deliberately blocks that
install method on every platform. Use one of these instead:

```
# Windows (PowerShell) — install Scoop first if you don't have it:
#   irm get.scoop.sh | iex
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Mac
brew install supabase/tap/supabase

# Linux
brew install supabase/tap/supabase   # if you have Homebrew on Linux
# otherwise see https://github.com/supabase/cli#install-the-cli for a direct download
```

Then log in, connect to your project, and deploy:

```
supabase login
supabase link --project-ref your-project-ref   # find this in Supabase → Project Settings → General
supabase functions deploy mom-chat delete-account revenuecat-webhook
supabase secrets set GEMINI_API_KEY=paste-your-key-here

# Note: setting GEMINI_API_KEY is optional for testing. If it's not
# set, `mom-chat` still runs everything for real (auth, saving
# messages, the weekly limit) but replies with an obvious placeholder
# instead of calling Gemini — no Google AI Studio key needed at all
# to test the rest of the app. Set the real key whenever you want real
# replies (it's free either way — see the services table above).
supabase secrets set REVENUECAT_WEBHOOK_SECRET=make-up-a-long-random-value
```

Then in RevenueCat's dashboard, add a webhook pointing at your
`revenuecat-webhook` function's URL, with that same random value as the
Authorization header.

### 5. Give the app its keys

Copy the example file and fill in the blanks — this file stays on your
computer only, it's already set up to be ignored by git:

```
cp config/local.json.example config/local.json
```

Open `config/local.json` and paste in the values from your Supabase,
RevenueCat, and Google Cloud accounts (`.env.example` at the repo root
explains where each value comes from).

### 6. Run the app

```
flutter run --dart-define-from-file=config/local.json
```

If you skip step 5, the app still opens, but shows a plain "missing
configuration" screen instead of crashing.

## What's working right now vs. still to build

**Working, connected to the real backend:**
- Signing up / logging in (email, Google, Apple)
- Onboarding questions save to your profile
- Adding tasks/habits, checking them off, streaks
- Chatting with Mom (with the free-plan weekly message limit enforced
  for real, not just shown in the app)
- Logging expenses and setting a budget
- Logging water/sleep/movement and setting health goals
- Deleting your account, logging out
- The Basic vs. Full plan gate, driven by RevenueCat

**Not built yet:**
- Push notifications / Mom's nagging messages (the plan for this is in
  our chat history, not built yet)
- The nightly "did you miss a streak" check needs to be scheduled in
  Supabase (the logic exists in `0002_streak_decay.sql`, it just needs
  to be turned on with `pg_cron` once you have a live project)
- Currency and measurement-unit settings are display-only for now
