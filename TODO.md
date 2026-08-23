# What's left to build

A running list of things that are designed/planned but not built yet, or
built partway. Kept separate from README.md so "how do I run this" and
"what's still missing" don't get mixed together. Update this file
whenever something here gets finished, or something new gets deferred.

Each item notes roughly how big it is, so it's easy to pick something
that fits the time you have.

## Not started

- **Push notifications** (task reminders, Mom's motivational nudges, the
  "haven't heard from you today" nudge). Nothing exists yet — no
  permission request, no scheduling, no notification content. Medium-large:
  needs Firebase Cloud Messaging set up, local-notification scheduling
  for due-time reminders, and a server-side job to send the
  personality-driven ones.
- **Data export** ("download my data") — explicitly cut from scope
  earlier, not planned unless asked for again.
- **2FA / app lock** — explicitly cut from scope earlier, not planned
  unless asked for again.

## Built but not switched on

- **Nightly streak-breaking.** The logic is done and tested
  (`supabase/migrations/0002_streak_decay.sql`, function
  `decay_streaks()`) but nothing calls it on a schedule yet. Needs the
  `pg_cron` extension turned on in the Supabase project, then one line:
  ```sql
  select cron.schedule('decay-streaks', '5 0 * * *', 'select public.decay_streaks();');
  ```
  Small — a few minutes once there's a live project.

## Half-built: Settings screen

Several rows in Settings are just static UI right now — they show but
don't do anything when tapped. Each is small on its own:

- **Change email** — shows the current email, no edit flow
- **Change password** — no edit flow
- **Manage subscription** — should deep-link to the iOS/Android
  subscription management page; currently a dead row
- **Change Mom's avatar** — should reopen the avatar picker; currently
  a dead row, and doesn't show which avatar is currently selected
- **Check-in frequency** — always shows the hardcoded text "A few times
  a day" instead of what the user actually picked in onboarding, and
  isn't editable
- **Appearance** — always shows "System", no actual light/dark override
  (the app *does* already follow the system theme automatically — this
  row just can't override that choice yet)
- **Help & contact support**, **Terms of Service**, **Privacy Policy**,
  **Open-source licenses** — all dead rows, no content or links wired
  up yet

## Half-built: enforcement that's client-side only

These show the right warning in the app UI, but a modified/fake client
could bypass them, because the real check only exists in the Flutter
code, not in the database or a server function:

- **Basic plan's 5 active task/habit cap** — Tasks screen warns and
  blocks the "+" button in the UI, but the database will happily accept
  a 6th task from any request that skips the app. (Compare: the chat
  weekly-message cap *is* enforced for real, inside the `mom-chat` edge
  function — that's the pattern to copy here.)

## Half-built: Finance

- **Per-category budgets** — the database already supports a budget
  per category (`budgets.category`), but the UI only ever sets the one
  "overall" budget. Small-medium: mostly UI work, the data model is
  ready.
- **Receipt photos, bank-linking** — explicitly out of scope (manual
  entry only was the decision), not planned.

## Needs external setup, not app code

- **Google Sign-In** — the code path exists (`AuthService.signInWithGoogle`)
  but needs a real Google Cloud OAuth client configured to actually work.
- **Apple Sign-In** — same, needs Apple Developer Program setup (Mac
  required to fully test).
- **Real subscription purchases** — RevenueCat integration is wired up,
  but testing an actual purchase needs App Store Connect / Google Play
  Console products configured, which needs paid developer accounts.

## Fixed, not deferred (for reference)

Not a to-do — noted here so it's not mistaken for one later:

- ~~Crash on Flutter Web from `Platform.isIOS` checks~~ — fixed for
  good with a `kIsWeb` guard; behaves identically on real iOS/Android,
  see the commit that added this file's first version for the full
  explanation.
