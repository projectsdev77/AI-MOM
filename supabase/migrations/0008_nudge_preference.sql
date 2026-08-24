-- Lets a user opt out of Mom's proactive nudge pushes (the on-device
-- task-reminder notifications in NotificationService are unaffected —
-- this only controls the server-sent "you've got incomplete tasks"
-- nudge from send-nudges).
alter table public.profiles
  add column if not exists push_nudges_enabled boolean not null default true;
