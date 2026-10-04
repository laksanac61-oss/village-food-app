-- Shop income reports (day / month / year) and 1-5 star customer ratings shown when choosing a shop.
-- Income counts completed orders only, food total only (the delivery fee goes to the rider),
-- in Thai time, on the booked time for pre-orders. Safe to run more than once.

-- ---------------------------------------------------------------- income

create or replace function shop_revenue(p_shop_id uuid, p_unit text, p_from date, p_to date)
returns table (bucket date, orders int, food numeric, cash numeric, promptpay numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (owns_shop(p_shop_id) or is_admin()) then raise exception 'not allowed'; end if;
  if p_unit not in ('day', 'month', 'year') then raise exception 'bad unit'; end if;
  return query
    select date_trunc(p_unit, coalesce(o.scheduled_for, o.created_at) at time zone 'Asia/Bangkok')::date,
           count(*)::int,
           sum(o.food_total),
           sum(o.food_total) filter (where o.food_payment_method = 'cash'),
           sum(o.food_total) filter (where o.food_payment_method = 'promptpay')
      from orders o
     where o.shop_id = p_shop_id
       and o.status = 'completed'
       and (coalesce(o.scheduled_for, o.created_at) at time zone 'Asia/Bangkok')::date between p_from and p_to
     group by 1
     order by 1;
end;
$$;

create or replace function shop_top_items(p_shop_id uuid, p_from date, p_to date)
returns table (name text, qty int, amount numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (owns_shop(p_shop_id) or is_admin()) then raise exception 'not allowed'; end if;
  return query
    select i.name, sum(i.qty)::int, sum(i.qty * i.unit_price)
      from order_items i join orders o on o.id = i.order_id
     where o.shop_id = p_shop_id
       and o.status = 'completed'
       and (coalesce(o.scheduled_for, o.created_at) at time zone 'Asia/Bangkok')::date between p_from and p_to
     group by i.name
     order by 2 desc, 3 desc
     limit 10;
end;
$$;

-- ---------------------------------------------------------------- ratings

create table if not exists order_reviews (
  order_id uuid primary key references orders(id) on delete cascade,
  shop_id uuid not null references shops(id) on delete cascade,
  customer_id uuid not null references profiles(id) on delete cascade,
  stars int not null check (stars between 1 and 5),
  comment text check (char_length(comment) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists order_reviews_shop on order_reviews (shop_id, created_at desc);
alter table order_reviews enable row level security;

drop policy if exists "read reviews" on order_reviews;
create policy "read reviews" on order_reviews for select
  using (customer_id = auth.uid() or owns_shop(shop_id) or is_admin());
-- writes go through rate_order()

-- The customer rates a completed order once; rating again replaces it.
create or replace function rate_order(p_order_id uuid, p_stars int, p_comment text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  o orders%rowtype;
begin
  select * into o from orders where id = p_order_id;
  if not found or o.customer_id is distinct from auth.uid() then raise exception 'order not found'; end if;
  if o.status <> 'completed' then raise exception 'rate after the order is completed'; end if;
  if p_stars not between 1 and 5 then raise exception 'stars must be 1-5'; end if;
  insert into order_reviews (order_id, shop_id, customer_id, stars, comment)
  values (o.id, o.shop_id, o.customer_id, p_stars, nullif(trim(left(p_comment, 300)), ''))
  on conflict (order_id) do update
    set stars = excluded.stars, comment = excluded.comment, created_at = now();
end;
$$;

-- Stars and order counts for every shop customers can see. Only totals are shared.
create or replace function shop_ratings()
returns table (shop_id uuid, stars numeric, reviews int, orders int)
language sql stable security definer set search_path = public as $$
  select s.id,
         (select round(avg(r.stars), 1) from order_reviews r where r.shop_id = s.id),
         (select count(*)::int from order_reviews r where r.shop_id = s.id),
         (select count(*)::int from orders o where o.shop_id = s.id and o.status = 'completed')
    from shops s
   where s.is_active and auth.uid() is not null;
$$;

-- Latest comments for a shop's page; no names, so customers can write freely.
create or replace function shop_reviews(p_shop_id uuid)
returns table (stars int, comment text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.stars, r.comment, r.created_at
    from order_reviews r
   where r.shop_id = p_shop_id and auth.uid() is not null
   order by r.created_at desc
   limit 20;
$$;

notify pgrst, 'reload schema';
