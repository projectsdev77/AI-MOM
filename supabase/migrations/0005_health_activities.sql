-- Custom "stay active" activities (e.g. "Tennis", target 60 min/day) —
-- same shape as tasks (title + a per-day log), but tracking minutes
-- against a daily target instead of a done/not-done checkbox.
create table public.health_activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  target_minutes int not null default 30,
  created_at timestamptz not null default now(),
  archived_at timestamptz
);

alter table public.health_activities enable row level security;

create policy "health_activities: owner all" on public.health_activities
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.health_activity_logs (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.health_activities (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  log_date date not null default (now() at time zone 'utc')::date,
  minutes int not null default 0,
  unique (activity_id, log_date)
);

create index health_activity_logs_activity_date_idx
  on public.health_activity_logs (activity_id, log_date);

alter table public.health_activity_logs enable row level security;

create policy "health_activity_logs: owner all" on public.health_activity_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
