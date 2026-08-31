/// Shared between onboarding (where it's first picked) and Settings
/// (where it can be changed later) so the two never drift apart.
///
/// The last entry exists purely to test the nudge pipeline end-to-end
/// (onboarding write -> profile column -> cron -> edge function -> push)
/// without waiting an hour between nudges — see
/// supabase/migrations/0011_nudge_test_frequency.sql. It still needs the
/// pg_cron schedule itself tightened (normally hourly) to actually be
/// reachable; that's a manual, temporary toggle in the Supabase SQL
/// editor, not something this app or its migrations do on their own.
const checkInFrequencyOptions = [
  'Once a day',
  'Twice a day',
  'Every 3 hours',
  'Every hour',
  'Every 2 minutes (testing)',
];
