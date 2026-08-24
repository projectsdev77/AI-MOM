-- Push notifications: profiles.fcm_token is the device token the
-- send-nudges edge function sends to; last_nudged_at stops the same
-- user getting nudged more than once per run.
alter table profiles
  add column if not exists fcm_token text,
  add column if not exists last_nudged_at timestamptz;
