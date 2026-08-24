-- The Basic plan's 5 active task/habit cap was only ever enforced in
-- the Flutter UI (see TODO.md) — a request that skips the app could
-- insert a 6th task for a Basic user. Enforce it for real with a
-- trigger, mirroring how the weekly chat cap is enforced in the
-- mom-chat edge function rather than trusted to the client.
create function public.enforce_basic_task_cap()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  user_plan text;
  active_count int;
begin
  select plan into user_plan from public.profiles where id = new.user_id;

  if user_plan = 'basic' then
    select count(*) into active_count
      from public.tasks
      where user_id = new.user_id and archived_at is null;

    if active_count >= 5 then
      raise exception 'basic_task_cap_reached' using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

create trigger enforce_basic_task_cap
  before insert on public.tasks
  for each row execute function public.enforce_basic_task_cap();

-- Turn on the nightly streak-decay job (logic already existed in
-- 0002_streak_decay.sql, just never scheduled). Requires the pg_cron
-- extension — if this errors with "extension pg_cron is not
-- available", enable it first via Supabase Dashboard -> Database ->
-- Extensions, then re-run just the lines below.
create extension if not exists pg_cron with schema extensions;

select cron.schedule('decay-streaks', '5 0 * * *', 'select public.decay_streaks();');
