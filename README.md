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
| [Firebase](https://console.firebase.google.com) | Delivers Mom's proactive push notifications ("you still have things on your list") | Free |

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
6. **Firebase** — console.firebase.google.com → Create a project (only
   needed for push notifications — see step 7 below; the app runs fine
   without it, Mom just won't be able to nudge you when you're not in
   the app)

### 3. Set up the database

In your Supabase project, open the SQL editor and run the files in
`supabase/migrations/` in order (0001, then 0002, then 0003, and so
on — always lowest number first). This creates all the tables the app
needs. If you already ran 0001 and 0002 before, you only need to run
the new ones you haven't run yet.

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
supabase functions deploy mom-chat delete-account revenuecat-webhook send-nudges
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

### 7. Set up push notifications (Firebase) — optional, skip for now if you'd rather

The app works completely fine without this step — it just means Mom
can't nudge you with a notification when the app isn't open. Everything
below is skippable and comes back to later.

**Client side (lets the app receive pushes):**

1. In your Firebase project, click **Add app** and register an
   **Android** app with package name `com.aimom.ai_mom` (this project's
   actual package name — must match exactly). Firebase will show you an
   API key, App ID, and Sender ID — you don't need to download
   `google-services.json`, this project reads those values from
   `config/local.json` instead.
2. When you're ready to test on iPhone, also register an **iOS** app
   with bundle ID `com.aimom.aiMom`, and separately, in Xcode, enable
   the "Push Notifications" capability on the Runner target (a native
   Xcode setting, not something a config file can do for you).
3. In Firebase → Project settings → General, copy these six values into
   `config/local.json`: `FIREBASE_API_KEY`, `FIREBASE_APP_ID` (use the
   Android app's, or iOS app's if you registered one),
   `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`,
   `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`.

**Server side (lets Mom actually send them, on a schedule):**

4. In Firebase → Project settings → Service accounts, click **Generate
   new private key**. This downloads a JSON file — paste its whole
   contents (not just one field) as a secret:
   ```
   supabase secrets set FIREBASE_SERVICE_ACCOUNT='paste the whole downloaded JSON file here'
   ```
5. In your Supabase dashboard, go to Database → Extensions and enable
   both `pg_cron` and `pg_net` (same place the streak-decay job's
   `pg_cron` requirement lives).
6. In the Supabase SQL editor, run these two commands once (find your
   project URL and **service role key** — not the anon key — under
   Project Settings → API):
   ```sql
   select vault.create_secret('https://YOUR-PROJECT.supabase.co', 'project_url');
   select vault.create_secret('YOUR-SERVICE-ROLE-KEY', 'service_role_key');
   ```

That's it — migration `0009_nudge_scheduling.sql` already scheduled the
job; it starts firing every 2 hours from here, nudging anyone with
incomplete tasks who hasn't been nudged recently and hasn't turned it
off in Settings.

## What's working right now vs. still to build

**Working, connected to the real backend:**
- Signing up / logging in (email or Google)
- Onboarding questions save to your profile
- Adding tasks/habits, checking them off, streaks, swipe-to-delete —
  the Basic plan's 5-task limit is enforced by the database itself,
  not just the app
- Chatting with Mom (with the free-plan weekly message limit enforced
  for real, not just shown in the app)
- Financial tracking: expenses, an overall budget, and per-category
  budgets with a visual tracker
- Health tracking: water/sleep/movement plus your own custom "stay
  active" activities (e.g. "Tennis, 60 min/day goal")
- Settings: change email/password, change Mom's avatar, light/dark
  override, currency choice, real Terms of Service/Privacy
  Policy/Help content
- Deleting your account, logging out
- The Basic vs. Full plan gate, driven by RevenueCat (though there's
  nothing real to *purchase* yet — see below)
- On-device reminders for any task/habit you give a time to — these
  fire even if Firebase (below) is never set up, since the phone
  handles them itself
- Mom's proactive "you still have things on your list" push
  notifications, once Firebase is set up (step 7) — off by default
  until then, and always toggleable in Settings either way

**Apple Sign-In: built, but not usable yet.** The code path exists
(`AuthService.signInWithApple`) and fails with a clear in-app message
rather than crashing, but it needs a paid Apple Developer Program
membership ($99/year) to actually configure and test — not something
that can be set up without that account. Use email or Google sign-in
until that's set up.

**A note on testing during development:** if you're running this via
`flutter run -d windows` (a Windows desktop build) while developing,
be aware that's not this app's real target platform, and two things
behave differently there than they will on a phone: Google Sign-In
fails with a clear "not supported on this desktop build" message
(the `google_sign_in` plugin has no Windows implementation at all —
test it on Android, iPhone, or in Chrome instead), and on-device
notifications silently do nothing (same reason — Android/iOS only).
Neither is a bug; both work as expected on Android/iOS.

**Not built yet:**
- Real subscription purchases — needs App Store Connect / Google Play
  Console products configured, which needs paid developer accounts
- Measurement-unit settings (currency works; a metric/imperial toggle
  doesn't, since nothing in the app currently displays a
  unit-dependent value like weight or distance)
- App Store / Play Store submission itself — icon, screenshots,
  listing copy, real device testing
