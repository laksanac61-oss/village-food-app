-- A LINE message to the shop when a new order is still not accepted after 3 minutes, as a backup to the
-- phone notification. Shops link their LINE once: the app shows a 6-digit code, the shop sends it to our
-- LINE Official Account, and the line-bot Edge Function saves their LINE user id. A cron job checks every
-- minute and only wakes the function when an order is overdue. Safe to run more than once.

alter table profiles add column if not exists line_user_id text unique;
alter table orders add column if not exists line_alerted_at timestamptz;

do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'cron') then
    create extension pg_cron;
  end if;
end $$;

-- ---------------------------------------------------------------- linking a shop's LINE

create table if not exists line_link_codes (
  code text primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  expires_at timestamptz not null
);
alter table line_link_codes enable row level security;

-- A fresh code for the signed-in member, valid 30 minutes.
create or replace function line_link_code()
returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  delete from line_link_codes where user_id = auth.uid() or expires_at < now();
  loop
    v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
    exit when not exists (select 1 from line_link_codes where code = v_code);
  end loop;
  insert into line_link_codes values (v_code, auth.uid(), now() + interval '30 minutes');
  return v_code;
end;
$$;

-- Whether the signed-in member has linked LINE (the id itself stays private).
create or replace function line_linked()
returns boolean language sql stable security definer set search_path = public as $$
  select line_user_id is not null from profiles where id = auth.uid();
$$;

create or replace function line_unlink()
returns void language sql security definer set search_path = public as $$
  update profiles set line_user_id = null where id = auth.uid();
$$;

-- Edge Function only: the shop sent its code in the LINE chat. Returns the member's name, or null.
create or replace function link_line_user(p_code text, p_line_user_id text)
returns text language plpgsql security definer set search_path = public as $$
declare v_user uuid; v_name text;
begin
  delete from line_link_codes where code = p_code and expires_at > now() returning user_id into v_user;
  if v_user is null then return null; end if;
  update profiles set line_user_id = null where line_user_id = p_line_user_id;
  update profiles set line_user_id = p_line_user_id where id = v_user returning full_name into v_name;
  return coalesce(v_name, '');
end;
$$;

-- ---------------------------------------------------------------- overdue orders

-- Edge Function only: pending orders older than 3 minutes not yet sent to LINE. Marks them as sent.
create or replace function claim_line_alerts()
returns table (line_user_id text, shop_name text, short_id text, minutes int, scheduled_for timestamptz)
language sql security definer set search_path = public as $$
  with due as (
    update orders o set line_alerted_at = now()
      from shops s join profiles p on p.id = s.owner_id
     where s.id = o.shop_id
       and p.line_user_id is not null
       and o.status = 'pending'
       and o.line_alerted_at is null
       and o.created_at < now() - interval '3 minutes'
       and o.created_at > now() - interval '2 hours'
    returning p.line_user_id, s.name, upper(left(o.id::text, 6)),
              floor(extract(epoch from now() - o.created_at) / 60)::int, o.scheduled_for
  )
  select * from due;
$$;

-- Run by cron every minute: wakes the line-bot function only when something is overdue.
create or replace function poke_line_alerts()
returns void language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from orders o join shops s on s.id = o.shop_id join profiles p on p.id = s.owner_id
     where p.line_user_id is not null and o.status = 'pending' and o.line_alerted_at is null
       and o.created_at < now() - interval '3 minutes' and o.created_at > now() - interval '2 hours'
  ) then
    perform net.http_post(
      url := 'https://lawwefqgureqmbtqkorl.supabase.co/functions/v1/line-bot',
      body := '{"action": "alerts"}'::jsonb,
      headers := '{"Content-Type": "application/json"}'::jsonb
    );
  end if;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'line-alerts';
  perform cron.schedule('line-alerts', '* * * * *', 'select public.poke_line_alerts()');
end $$;

revoke all on function link_line_user(text, text) from public;
revoke all on function claim_line_alerts() from public;
revoke all on function poke_line_alerts() from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function link_line_user(text, text) from anon, authenticated;
    revoke all on function claim_line_alerts() from anon, authenticated;
    revoke all on function poke_line_alerts() from anon, authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function link_line_user(text, text) to service_role;
    grant execute on function claim_line_alerts() to service_role;
  end if;
end $$;

notify pgrst, 'reload schema';
