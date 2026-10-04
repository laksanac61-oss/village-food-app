-- Pre-orders: customers book a time ahead (Thai lunch and dinner rush), the shop sees when to start cooking,
-- and customers living close together with times within 30 minutes are offered one delivery round.
-- Travel time is estimated from the map pins (straight-line distance x road factor at motorbike speed).
-- Safe to run more than once.

alter table orders add column if not exists scheduled_for timestamptz;  -- null = as soon as possible
alter table shops
  add column if not exists accepts_preorder boolean not null default true,
  add column if not exists prep_minutes int not null default 20;      -- how long one cooking round takes

create index if not exists orders_shop_scheduled on orders (shop_id, scheduled_for) where scheduled_for is not null;

-- Straight-line distance in km between two pins
create or replace function distance_km(lat1 double precision, lng1 double precision,
                                       lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)));
$$;

-- Old signature had no scheduled time; replace it so the API has one place_order.
drop function if exists place_order(uuid, jsonb, fulfillment_type, uuid, payment_method, payment_method, text);

create or replace function place_order(
  p_shop_id uuid,
  p_items jsonb,
  p_fulfillment fulfillment_type,
  p_zone_id uuid,
  p_food_payment payment_method,
  p_delivery_payment payment_method,
  p_address_note text,
  p_scheduled_for timestamptz default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_order uuid;
  v_shop shops%rowtype;
  v_fee numeric(10,2) := 0;
  v_item jsonb;
  v_menu menu_items%rowtype;
  v_total numeric(10,2) := 0;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;

  select * into v_shop from shops where id = p_shop_id;
  if not found or not v_shop.is_active then
    raise exception 'shop is closed';
  end if;
  if p_scheduled_for is null then
    if not v_shop.is_open then raise exception 'shop is closed'; end if;
  else
    -- a booking may be made while the shop is closed, e.g. in the morning for lunch
    if not v_shop.accepts_preorder then raise exception 'shop does not take pre-orders'; end if;
    if p_scheduled_for < now() + interval '30 minutes' then
      raise exception 'book at least 30 minutes ahead';
    end if;
    if p_scheduled_for > now() + interval '3 days' then
      raise exception 'book at most 3 days ahead';
    end if;
  end if;
  if p_food_payment = 'cash' and not v_shop.accepts_cash then
    raise exception 'shop does not accept cash';
  end if;
  if jsonb_array_length(coalesce(p_items, '[]'::jsonb)) = 0 then
    raise exception 'empty order';
  end if;

  if p_fulfillment = 'delivery' then
    select fee into v_fee from delivery_zones where id = p_zone_id;
    if not found then raise exception 'choose a delivery zone'; end if;
  end if;

  insert into orders (customer_id, shop_id, fulfillment, zone_id, delivery_fee,
                      food_payment_method, delivery_payment_method, address_note, scheduled_for)
  values (auth.uid(), p_shop_id, p_fulfillment,
          case when p_fulfillment = 'delivery' then p_zone_id end, v_fee,
          p_food_payment, coalesce(p_delivery_payment, 'cash'), p_address_note, p_scheduled_for)
  returning id into v_order;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_menu from menu_items
     where id = (v_item->>'menu_item_id')::uuid and shop_id = p_shop_id and is_available;
    if not found then raise exception 'menu item unavailable'; end if;
    if (v_item->>'qty')::int < 1 then raise exception 'bad quantity'; end if;
    insert into order_items (order_id, menu_item_id, name, unit_price, qty, note)
    values (v_order, v_menu.id, v_menu.name, v_menu.price, (v_item->>'qty')::int, v_item->>'note');
    v_total := v_total + v_menu.price * (v_item->>'qty')::int;
  end loop;

  update orders set food_total = v_total where id = v_order;
  return v_order;
end;
$$;

-- Before booking, a customer asks: is someone near me already booked within 30 minutes of my time?
-- Returns at most one booked time and how many orders share it; never who they are or where.
create or replace function nearby_preorder(p_shop_id uuid, p_time timestamptz,
                                           p_lat double precision, p_lng double precision,
                                           p_km double precision default 1.0)
returns table (slot timestamptz, orders int)
language sql stable security definer set search_path = public as $$
  select o.scheduled_for, count(*)::int
    from orders o
   where auth.uid() is not null
     and o.shop_id = p_shop_id
     and o.scheduled_for is not null
     and o.fulfillment = 'delivery'
     and o.status not in ('cancelled', 'completed')
     and o.dropoff_lat is not null
     and o.scheduled_for <> p_time
     and abs(extract(epoch from o.scheduled_for - p_time)) <= 30 * 60
     and distance_km(o.dropoff_lat, o.dropoff_lng, p_lat, p_lng) <= least(p_km, 3)
   group by o.scheduled_for
   order by abs(extract(epoch from o.scheduled_for - p_time)), count(*) desc
   limit 1;
$$;

notify pgrst, 'reload schema';
