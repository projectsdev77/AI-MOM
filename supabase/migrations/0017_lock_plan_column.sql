-- A signed-in user could set their own plan to 'full' with one request,
-- because the "owner update" policy on profiles covers every column.
-- This stops that: `plan` (and the RevenueCat id it is matched by) can only
-- be changed by the server — the revenuecat-webhook function (service role)
-- or someone in the SQL editor — never by a request made as a user.
--
-- Requests made as a user carry their id in auth.uid(); the service role and
-- the SQL editor have none, so they pass straight through.
create or replace function public.protect_plan_columns()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is not null
     and (new.plan is distinct from old.plan
          or new.revenuecat_app_user_id is distinct from old.revenuecat_app_user_id) then
    raise exception 'plan_is_managed_by_server' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_plan_columns on public.profiles;
create trigger protect_plan_columns
  before update of plan, revenuecat_app_user_id on public.profiles
  for each row execute function public.protect_plan_columns();
