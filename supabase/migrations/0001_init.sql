-- Village food ordering: initial schema
-- Roles: customer, shop_owner, rider, admin
-- All order/payment writes go through security-definer functions so each
-- role can only make the moves it is allowed to make.

create extension if not exists "pgcrypto";

create type user_role as enum ('customer', 'shop_owner', 'rider', 'admin');
create type order_status as enum (
  'pending',      -- placed, waiting for shop
  'accepted',     -- shop accepted
  'cooking',
  'ready',        -- ready for pickup / rider
  'picked_up',    -- rider has the food
  'delivering',
  'completed',
  'cancelled'
);
create type fulfillment_type as enum ('delivery', 'pickup');
create type payment_method as enum ('promptpay', 'cash');
create type payment_status as enum ('unpaid', 'slip_uploaded', 'confirmed', 'rejected');
create type rider_status as enum ('pending_approval', 'approved', 'suspended');

-- ---------------------------------------------------------------- tables

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null default 'customer',
  full_name text,
  phone text,
  house_no text,
  soi text,
  created_at timestamptz not null default now()
);

create table shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id),
  name text not null,
  description text,
  image_url text,
  phone text,
  promptpay_id text not null,               -- phone or citizen ID
  accepts_cash boolean not null default true,
  is_open boolean not null default false,
  is_active boolean not null default true,  -- admin can suspend
  created_at timestamptz not null default now()
);

create table menu_items (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  name text not null,
  description text,
  price numeric(10,2) not null check (price >= 0),
  image_url text,
  is_available boolean not null default true,
  sort_order int not null default 0
);

create table riders (
  id uuid primary key references profiles(id) on delete cascade,
  status rider_status not null default 'pending_approval',
  id_card_image_url text,
  photo_url text,
  vehicle_type text,
  plate_no text,
  promptpay_id text not null,
  is_online boolean not null default false,
  created_at timestamptz not null default now()
);

create table delivery_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null,                       -- e.g. 'ทั้งหมู่บ้าน', 'ซอย 1-5'
  fee numeric(10,2) not null check (fee >= 0)
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references profiles(id),
  shop_id uuid not null references shops(id),
  rider_id uuid references riders(id),
  status order_status not null default 'pending',
  fulfillment fulfillment_type not null default 'delivery',
  zone_id uuid references delivery_zones(id),
  food_total numeric(10,2) not null default 0,
  delivery_fee numeric(10,2) not null default 0,
  food_payment_method payment_method not null default 'promptpay',
  food_payment_status payment_status not null default 'unpaid',
  food_slip_path text,
  delivery_payment_method payment_method not null default 'cash',
  address_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  menu_item_id uuid references menu_items(id),
  name text not null,                       -- snapshot at order time
  unit_price numeric(10,2) not null,
  qty int not null check (qty > 0),
  note text
);

create index on orders (shop_id, status);
create index on orders (rider_id, status);
create index on orders (customer_id, created_at desc);

-- ---------------------------------------------------------------- helpers

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function owns_shop(p_shop uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from shops where id = p_shop and owner_id = auth.uid());
$$;

create or replace function is_active_rider() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from riders where id = auth.uid() and status = 'approved' and is_online);
$$;

-- New sign-ups get a customer profile automatically
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, phone)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'phone');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Only admins may change roles or rider approval
create or replace function guard_privileged_columns() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if is_admin() or auth.uid() is null then  -- auth.uid() null = service role / SQL editor
    return new;
  end if;
  -- nested ifs: plpgsql does not short-circuit, and each table has different columns
  if tg_table_name = 'profiles' then
    if new.role is distinct from old.role then
      raise exception 'only admin can change role';
    end if;
  elsif tg_table_name = 'riders' then
    if new.status is distinct from old.status then
      raise exception 'only admin can change rider status';
    end if;
  elsif tg_table_name = 'shops' then
    if new.is_active is distinct from old.is_active or new.owner_id is distinct from old.owner_id then
      raise exception 'only admin can change shop activation or owner';
    end if;
  end if;
  return new;
end;
$$;

create trigger guard_profiles before update on profiles
  for each row execute function guard_privileged_columns();
create trigger guard_riders before update on riders
  for each row execute function guard_privileged_columns();
create trigger guard_shops before update on shops
  for each row execute function guard_privileged_columns();

-- ---------------------------------------------------------------- order RPCs

-- Customer places an order; totals are computed here, not trusted from the app.
-- p_items: [{"menu_item_id": uuid, "qty": int, "note": text}]
create or replace function place_order(
  p_shop_id uuid,
  p_items jsonb,
  p_fulfillment fulfillment_type,
  p_zone_id uuid,
  p_food_payment payment_method,
  p_delivery_payment payment_method,
  p_address_note text
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
  if not found or not v_shop.is_active or not v_shop.is_open then
    raise exception 'shop is closed';
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
                      food_payment_method, delivery_payment_method, address_note)
  values (auth.uid(), p_shop_id, p_fulfillment,
          case when p_fulfillment = 'delivery' then p_zone_id end, v_fee,
          p_food_payment, coalesce(p_delivery_payment, 'cash'), p_address_note)
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

-- Customer attaches a payment slip (file already uploaded to storage bucket 'slips')
create or replace function submit_slip(p_order_id uuid, p_path text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update orders
     set food_slip_path = p_path, food_payment_status = 'slip_uploaded', updated_at = now()
   where id = p_order_id and customer_id = auth.uid()
     and food_payment_method = 'promptpay' and status <> 'cancelled';
  if not found then raise exception 'order not found'; end if;
end;
$$;

-- Shop confirms or rejects the payment
create or replace function review_payment(p_order_id uuid, p_ok boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  update orders o
     set food_payment_status = case when p_ok then 'confirmed' else 'rejected' end::payment_status,
         updated_at = now()
   where o.id = p_order_id and (owns_shop(o.shop_id) or is_admin());
  if not found then raise exception 'not allowed'; end if;
end;
$$;

-- Status moves allowed per role
create or replace function set_order_status(p_order_id uuid, p_status order_status) returns void
language plpgsql security definer set search_path = public as $$
declare
  o orders%rowtype;
  allowed boolean := false;
begin
  select * into o from orders where id = p_order_id for update;
  if not found then raise exception 'order not found'; end if;

  if is_admin() then
    allowed := true;
  elsif owns_shop(o.shop_id) then
    allowed := (o.status, p_status) in (
      ('pending','accepted'), ('pending','cancelled'), ('accepted','cooking'),
      ('cooking','ready'), ('accepted','ready'))
      or (o.fulfillment = 'pickup' and o.status = 'ready' and p_status = 'completed');
  elsif o.rider_id = auth.uid() then
    allowed := (o.status, p_status) in (
      ('ready','picked_up'), ('picked_up','delivering'), ('delivering','completed'));
  elsif o.customer_id = auth.uid() then
    allowed := o.status = 'pending' and p_status = 'cancelled';
  end if;

  if not allowed then
    raise exception 'cannot move order from % to %', o.status, p_status;
  end if;
  update orders set status = p_status, updated_at = now() where id = p_order_id;
end;
$$;

-- First online rider to accept gets the job
create or replace function claim_order(p_order_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  if not is_active_rider() then return false; end if;
  update orders
     set rider_id = auth.uid(), updated_at = now()
   where id = p_order_id and rider_id is null and fulfillment = 'delivery'
     and status in ('accepted', 'cooking', 'ready');
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

-- ---------------------------------------------------------------- RLS

alter table profiles enable row level security;
alter table shops enable row level security;
alter table menu_items enable row level security;
alter table riders enable row level security;
alter table delivery_zones enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;

create policy "read own profile" on profiles for select
  using (id = auth.uid() or is_admin()
         -- shop and rider see their customer; customer and shop see their rider
         or exists (select 1 from orders o where o.customer_id = profiles.id
                    and (o.rider_id = auth.uid() or owns_shop(o.shop_id)))
         or exists (select 1 from orders o where o.rider_id = profiles.id
                    and (o.customer_id = auth.uid() or owns_shop(o.shop_id))));
create policy "update own profile" on profiles for update
  using (id = auth.uid() or is_admin());

create policy "read shops" on shops for select
  using (is_active or owner_id = auth.uid() or is_admin());
create policy "owner updates shop" on shops for update
  using (owner_id = auth.uid() or is_admin());
create policy "admin creates shop" on shops for insert with check (is_admin());
create policy "admin deletes shop" on shops for delete using (is_admin());

create policy "read menu" on menu_items for select using (true);
create policy "owner writes menu" on menu_items for all
  using (owns_shop(shop_id) or is_admin()) with check (owns_shop(shop_id) or is_admin());

create policy "read riders" on riders for select
  using (id = auth.uid() or is_admin()
         or exists (select 1 from orders o where o.rider_id = riders.id
                    and (o.customer_id = auth.uid() or owns_shop(o.shop_id))));
create policy "rider registers" on riders for insert
  with check (id = auth.uid() and status = 'pending_approval');
create policy "rider updates self" on riders for update
  using (id = auth.uid() or is_admin());

create policy "read zones" on delivery_zones for select using (true);
create policy "admin writes zones" on delivery_zones for all
  using (is_admin()) with check (is_admin());

create policy "read orders" on orders for select using (
  customer_id = auth.uid() or rider_id = auth.uid() or owns_shop(shop_id) or is_admin()
  or (rider_id is null and fulfillment = 'delivery'
      and status in ('accepted','cooking','ready') and is_active_rider())
);
-- no insert/update policies: orders change only through the functions above

create policy "read order items" on order_items for select
  using (exists (select 1 from orders o where o.id = order_id));

-- ---------------------------------------------------------------- storage

insert into storage.buckets (id, name, public) values
  ('slips', 'slips', false),
  ('rider-docs', 'rider-docs', false),
  ('images', 'images', true)
on conflict (id) do nothing;

-- slips/<customer uid>/<order id>.jpg
create policy "customer uploads own slip" on storage.objects for insert
  with check (bucket_id = 'slips' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "slip readable by order parties" on storage.objects for select
  using (bucket_id = 'slips' and exists (
    select 1 from public.orders o
     where o.food_slip_path = storage.objects.name
       and (o.customer_id = auth.uid() or public.owns_shop(o.shop_id) or public.is_admin())));

-- images/<uid>/... public menu and shop photos
create policy "signed-in users upload images" on storage.objects for insert
  with check (bucket_id = 'images' and (storage.foldername(name))[1] = auth.uid()::text);

-- rider-docs/<rider uid>/... ID card and photo, private to the rider and admin
create policy "rider uploads own docs" on storage.objects for insert
  with check (bucket_id = 'rider-docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "rider docs readable by owner and admin" on storage.objects for select
  using (bucket_id = 'rider-docs'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- Live updates for order screens
alter publication supabase_realtime add table orders;
