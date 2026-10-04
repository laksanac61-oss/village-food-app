-- Phone notifications for shops (Firebase Cloud Messaging), so a new order or payment slip reaches the shop
-- even when the app is closed. The Android app saves its device token here; a trigger queues an event and
-- asks the notify-shop Edge Function to send it. The function only sends events that are queued and unsent,
-- so calling it by hand can't make extra notifications. Safe to run more than once.

-- pg_net lets the database call the Edge Function (already present on Supabase, a stub in local tests)
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'net') then
    create extension pg_net;
  end if;
end $$;

-- ---------------------------------------------------------------- device tokens

create table if not exists push_tokens (
  token text primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);
create index if not exists push_tokens_user on push_tokens(user_id);
alter table push_tokens enable row level security;
-- no table policies: the app goes through the functions below

-- A phone has one token; whoever signs in on it last gets its notifications.
create or replace function save_push_token(p_token text, p_platform text default 'android')
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if length(coalesce(p_token, '')) not between 20 and 4096 then raise exception 'bad token'; end if;
  insert into push_tokens (token, user_id, platform) values (p_token, auth.uid(), p_platform)
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end;
$$;

-- Called when signing out, so the phone stops getting the previous account's orders.
create or replace function forget_push_token(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from push_tokens where token = p_token and user_id = auth.uid();
$$;

-- ---------------------------------------------------------------- queued notifications

create table if not exists push_events (
  id bigserial primary key,
  order_id uuid not null references orders(id) on delete cascade,
  kind text not null check (kind in ('new_order', 'slip')),
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
alter table push_events enable row level security;

create or replace function queue_shop_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_kind text;
  v_id bigint;
begin
  if tg_op = 'INSERT' then
    v_kind := 'new_order';
  elsif new.food_payment_status = 'slip_uploaded' and old.food_payment_status is distinct from 'slip_uploaded' then
    v_kind := 'slip';
  else
    return new;
  end if;
  insert into push_events (order_id, kind) values (new.id, v_kind) returning id into v_id;
  -- sent after the order is saved; a failure here must never block the order
  begin
    perform net.http_post(
      url := 'https://lawwefqgureqmbtqkorl.supabase.co/functions/v1/notify-shop',
      body := jsonb_build_object('event_id', v_id),
      headers := '{"Content-Type": "application/json"}'::jsonb
    );
  exception when others then
    null;
  end;
  return new;
end;
$$;

drop trigger if exists orders_shop_push on orders;
create trigger orders_shop_push after insert or update of food_payment_status on orders
  for each row execute function queue_shop_push();

-- Marks one queued event as sent and returns what to send and to which phones. Only the Edge Function
-- (service role) may call it; an event already sent returns nothing.
create or replace function claim_push_event(p_event_id bigint)
returns table (token text, title text, body text, order_id uuid)
language plpgsql security definer set search_path = public as $$
declare
  e push_events;
  o orders;
  v_title text;
  v_body text;
  v_short text;
begin
  update push_events set sent_at = now()
   where id = p_event_id and sent_at is null and created_at > now() - interval '1 hour'
   returning * into e;
  if e.id is null then return; end if;
  select * into o from orders where id = e.order_id;
  v_short := upper(left(o.id::text, 6));
  if e.kind = 'new_order' then
    v_title := case when o.scheduled_for is null then 'ออเดอร์ใหม่' else 'มีการจองล่วงหน้า' end;
    v_body := '#' || v_short || ' · ' ||
              case when o.fulfillment = 'delivery' then 'ส่งถึงบ้าน' else 'มารับเองที่ร้าน' end ||
              case when o.food_total > 0 then ' · ฿' || trim(to_char(o.food_total, 'FM999,999,990.##'), '.') else '' end ||
              case when o.scheduled_for is not null
                   then ' · รับ ' || to_char(o.scheduled_for at time zone 'Asia/Bangkok', 'DD/MM HH24:MI') || ' น.'
                   else '' end;
  else
    v_title := 'ลูกค้าส่งสลิปแล้ว';
    v_body := '#' || v_short || ' · ค่าอาหาร ฿' || trim(to_char(o.food_total, 'FM999,999,990.##'), '.') ||
              ' กดเพื่อตรวจสลิป';
  end if;
  return query
    select t.token, v_title, v_body, o.id
      from push_tokens t join shops s on s.owner_id = t.user_id
     where s.id = o.shop_id;
end;
$$;

-- Removes tokens Firebase says are no longer valid (app uninstalled).
create or replace function drop_push_token(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from push_tokens where token = p_token;
$$;

revoke all on function claim_push_event(bigint) from public;
revoke all on function drop_push_token(text) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function claim_push_event(bigint) from anon, authenticated;
    revoke all on function drop_push_token(text) from anon, authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function claim_push_event(bigint) to service_role;
    grant execute on function drop_push_token(text) to service_role;
  end if;
end $$;

notify pgrst, 'reload schema';
