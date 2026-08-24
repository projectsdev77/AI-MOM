-- Four extra onboarding questions (daily routine, living situation,
-- motivation style, current stressor) so Mom has more real context to
-- work with, not just goals/procrastination. All optional — someone
-- can skip any of them during onboarding, so these stay nullable.
alter table profiles
  add column if not exists daily_routine text,
  add column if not exists living_situation text,
  add column if not exists motivation_style text,
  add column if not exists current_stressor text;
