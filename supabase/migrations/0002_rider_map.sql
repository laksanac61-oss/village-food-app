-- Map support: customer home pin and live rider position on each order.

alter table profiles
  add column home_lat double precision,
  add column home_lng double precision;

alter table orders
  add column dropoff_lat double precision,
  add column dropoff_lng double precision,
  add column rider_lat double precision,
  add column rider_lng double precision,
  add column rider_loc_at timestamptz;

-- Customer sets where the food should go (right after placing, or later while open)
create or replace function set_order_dropoff(p_order_id uuid, p_lat double precision, p_lng double precision)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'bad coordinates';
  end if;
  update orders
     set dropoff_lat = p_lat, dropoff_lng = p_lng, updated_at = now()
   where id = p_order_id and customer_id = auth.uid()
     and status not in ('completed', 'cancelled');
  if not found then raise exception 'order not found'; end if;
end;
$$;

-- Assigned rider reports their position while carrying the food
create or replace function update_rider_location(p_order_id uuid, p_lat double precision, p_lng double precision)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'bad coordinates';
  end if;
  update orders
     set rider_lat = p_lat, rider_lng = p_lng, rider_loc_at = now()
   where id = p_order_id and rider_id = auth.uid()
     and status in ('ready', 'picked_up', 'delivering');
  if not found then raise exception 'not delivering this order'; end if;
end;
$$;
