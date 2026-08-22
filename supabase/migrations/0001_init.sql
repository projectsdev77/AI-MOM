-- AI Mom initial schema.
-- Every table is user-scoped and RLS-locked to auth.uid() = user_id.
-- Plan/entitlement state is owned by RevenueCat; `profiles.plan` is a
-- cache updated by the RevenueCat webhook (see functions/revenuecat-webhook),
-- never written to directly by the client.

create type task_category as enum ('chores', 'work', 'health', 'money', 'personal');
create type recurrence_type as enum ('none', 'daily', 'weekly', 'custom');
create type app_plan as enum ('basic', 'full');

-- ---------------------------------------------------------------------
-- profiles: one row per auth.users row, created by the trigger below.
-- ---------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  mom_avatar_style text not null default 'terracotta',
  plan app_plan not null default 'basic',
  check_in_frequency text not null default 'A few times a day',
  currency text not null default 'USD',
  units text not null default 'imperial',
  goals text[] not null default '{}',
  procrastination_areas text[] not null default '{}',
  revenuecat_app_user_id text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: owner read" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles: owner update" on public.profiles
  for update using (auth.uid() = id);

-- Auto-create a profile row whenever a new auth user signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- tasks / task_completions: the unified task+habit model. A one-off
-- task is `recurrence = 'none'`; a habit is any other recurrence and
-- accrues streak_count via a completion-insert trigger.
-- ---------------------------------------------------------------------
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  category task_category not null default 'personal',
  recurrence recurrence_type not null default 'none',
  recurrence_days smallint[], -- ISO weekday numbers (1=Mon..7=Sun) for 'custom'
  due_time time,
  streak_count integer not null default 0,
  streak_freezes_available integer not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

create index tasks_user_id_idx on public.tasks (user_id) where archived_at is null;

alter table public.tasks enable row level security;

create policy "tasks: owner all" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.task_completions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  completed_date date not null default (now() at time zone 'utc')::date,
  created_at timestamptz not null default now(),
  unique (task_id, completed_date)
);

alter table public.task_completions enable row level security;

create policy "task_completions: owner all" on public.task_completions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Bump streak_count on every new completion. Streak *decay* (breaking a
-- streak after a missed day, minus any freeze) runs as a nightly
-- scheduled job — see functions/streak-decay — since it has to act on
-- tasks with no completion "event" to hang a trigger off of.
create function public.handle_task_completion()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.tasks
  set streak_count = streak_count + 1
  where id = new.task_id;
  return new;
end;
$$;

create trigger on_task_completed
  after insert on public.task_completions
  for each row execute function public.handle_task_completion();

-- Mirror of the above for un-checking a task (the dashboard/task list
-- checkbox is a toggle, not a one-way mark).
create function public.handle_task_uncompletion()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.tasks
  set streak_count = greatest(streak_count - 1, 0)
  where id = old.task_id;
  return old;
end;
$$;

create trigger on_task_uncompleted
  after delete on public.task_completions
  for each row execute function public.handle_task_uncompletion();

-- ---------------------------------------------------------------------
-- chat_sessions / chat_messages
-- ---------------------------------------------------------------------
create table public.chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default 'New chat',
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);

alter table public.chat_sessions enable row level security;

create policy "chat_sessions: owner all" on public.chat_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.chat_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  from_mom boolean not null,
  content text not null,
  image_path text,
  created_at timestamptz not null default now()
);

create index chat_messages_session_idx on public.chat_messages (session_id, created_at);

alter table public.chat_messages enable row level security;

create policy "chat_messages: owner all" on public.chat_messages
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- expenses / budgets (Full plan only — enforced in the client + edge
-- functions, not by RLS, since RLS can't see RevenueCat entitlements)
-- ---------------------------------------------------------------------
create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  amount_cents integer not null check (amount_cents >= 0),
  category text not null,
  note text,
  spent_at date not null default (now() at time zone 'utc')::date,
  created_at timestamptz not null default now()
);

create index expenses_user_spent_at_idx on public.expenses (user_id, spent_at desc);

alter table public.expenses enable row level security;

create policy "expenses: owner all" on public.expenses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  -- 'overall' = the whole-month budget; anything else is a per-category
  -- budget. Deliberately NOT nullable: a nullable category plus a plain
  -- `unique (user_id, category)` would silently allow duplicate overall
  -- budgets, since Postgres treats every NULL as distinct from every
  -- other NULL for uniqueness purposes. A plain string sentinel avoids
  -- that trap and lets a normal upsert(onConflict: 'user_id,category')
  -- work correctly.
  category text not null default 'overall',
  amount_cents integer not null check (amount_cents >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, category)
);

alter table public.budgets enable row level security;

create policy "budgets: owner all" on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- health_logs (one row per user per day) / health_goals (one row per user)
-- ---------------------------------------------------------------------
create table public.health_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_date date not null default (now() at time zone 'utc')::date,
  water_count integer not null default 0,
  sleep_hours numeric(4, 1),
  workout_minutes integer not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, log_date)
);

alter table public.health_logs enable row level security;

create policy "health_logs: owner all" on public.health_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.health_goals (
  user_id uuid primary key references auth.users (id) on delete cascade,
  water_target integer not null default 8,
  sleep_target_hours numeric(4, 1) not null default 8,
  workout_target_minutes integer not null default 30,
  updated_at timestamptz not null default now()
);

alter table public.health_goals enable row level security;

create policy "health_goals: owner all" on public.health_goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
