-- A device's push token should belong to exactly one account: whoever is
-- signed in on it. Nothing enforced that. When someone signed out and a
-- different account signed in on the same phone, the first account's row
-- kept the token (signing out never cleared it), so the server went on
-- nudging that phone for BOTH accounts, including the one nobody was
-- signed into any more.
--
-- The app now clears its token on sign-out, but a trigger is the part that
-- can't be skipped (an offline sign-out, an old app version, a crash): when
-- a profile is given a token, every OTHER profile holding that same token
-- lets go of it. security definer, because row-level security rightly stops
-- one user's session from touching another user's row.
create or replace function public.release_duplicate_fcm_token()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.fcm_token is not null then
    update public.profiles
      set fcm_token = null
      where fcm_token = new.fcm_token
        and id <> new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists release_duplicate_fcm_token on public.profiles;
create trigger release_duplicate_fcm_token
  before update of fcm_token on public.profiles
  for each row execute function public.release_duplicate_fcm_token();

-- One-off cleanup of what already exists: any token currently shared by
-- more than one account is cleared from ALL of them. There's no telling
-- which one is the account actually signed in, but whoever is will put it
-- straight back: the app registers its token on every launch and sign-in.
-- The ones that are genuinely signed out stay quiet, which is the point.
update public.profiles
  set fcm_token = null
  where fcm_token in (
    select fcm_token
    from public.profiles
    where fcm_token is not null
    group by fcm_token
    having count(*) > 1
  );
