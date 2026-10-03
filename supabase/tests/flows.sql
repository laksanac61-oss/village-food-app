-- End-to-end checks of the order flow and role rules. Run with scripts/test_db.sh.
\set ON_ERROR_STOP 1
create role app_user;
grant usage on schema public to app_user;
grant select, insert, update, delete on all tables in schema public to app_user;
grant execute on all functions in schema public to app_user;
grant usage on schema auth, storage to app_user;

insert into auth.users (id, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', '{"full_name":"Admin"}'),
  ('00000000-0000-0000-0000-00000000000b', '{"full_name":"Shop owner"}'),
  ('00000000-0000-0000-0000-00000000000c', '{"full_name":"Customer"}'),
  ('00000000-0000-0000-0000-00000000000d', '{"full_name":"Rider"}'),
  ('00000000-0000-0000-0000-00000000000e', '{"full_name":"Rider 2"}');
update profiles set role = 'admin' where id = '00000000-0000-0000-0000-00000000000a';
update profiles set role = 'shop_owner' where id = '00000000-0000-0000-0000-00000000000b';

set role app_user;

-- admin sets up shop, zone
set test.uid = '00000000-0000-0000-0000-00000000000a';
insert into shops (id, owner_id, name, promptpay_id, is_open)
  values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'ข้าวมันไก่', '0812345678', true);
insert into delivery_zones (id, name, fee) values ('20000000-0000-0000-0000-000000000001', 'ทั้งหมู่บ้าน', 15);

-- shop adds menu
set test.uid = '00000000-0000-0000-0000-00000000000b';
insert into menu_items (id, shop_id, name, price) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'ข้าวมันไก่', 50),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'น้ำซุป', 10);

-- riders register; rider cannot self-approve
set test.uid = '00000000-0000-0000-0000-00000000000d';
insert into riders (id, promptpay_id) values ('00000000-0000-0000-0000-00000000000d', '0899999999');
do $$ begin
  update riders set status = 'approved' where id = auth.uid();
  raise exception 'FAIL: rider self-approved';
exception when others then
  if sqlerrm not like 'only admin%' then raise; end if;
end $$;
set test.uid = '00000000-0000-0000-0000-00000000000e';
insert into riders (id, promptpay_id, is_online) values ('00000000-0000-0000-0000-00000000000e', '0888888888', true);

set test.uid = '00000000-0000-0000-0000-00000000000a';
update riders set status = 'approved';
set test.uid = '00000000-0000-0000-0000-00000000000d';
update riders set is_online = true where id = auth.uid();

-- customer cannot become admin
set test.uid = '00000000-0000-0000-0000-00000000000c';
do $$ begin
  update profiles set role = 'admin' where id = auth.uid();
  raise exception 'FAIL: customer became admin';
exception when others then
  if sqlerrm not like 'only admin%' then raise; end if;
end $$;

-- customer places order; total computed server-side
select place_order('10000000-0000-0000-0000-000000000001',
  '[{"menu_item_id":"30000000-0000-0000-0000-000000000001","qty":2},
    {"menu_item_id":"30000000-0000-0000-0000-000000000002","qty":1}]',
  'delivery', '20000000-0000-0000-0000-000000000001', 'promptpay', 'cash', 'บ้านเลขที่ 9') as oid \gset
do $$ begin
  if (select food_total from orders) <> 110 or (select delivery_fee from orders) <> 15 then
    raise exception 'FAIL: totals wrong';
  end if;
end $$;
-- customer cannot write orders directly
do $$ begin
  update orders set status = 'completed';
  if exists (select 1 from orders where status = 'completed') then raise exception 'FAIL: direct update'; end if;
end $$;
select submit_slip(:'oid', '00000000-0000-0000-0000-00000000000c/x.jpg');

-- customer cannot skip ahead
do $$ begin
  perform set_order_status((select id from orders), 'completed');
  raise exception 'FAIL: customer completed order';
exception when others then
  if sqlerrm not like 'cannot move order%' then raise; end if;
end $$;

-- shop confirms payment and accepts
set test.uid = '00000000-0000-0000-0000-00000000000b';
select review_payment(:'oid', true);
select set_order_status(:'oid', 'accepted');

-- both riders see the job; first claim wins
set test.uid = '00000000-0000-0000-0000-00000000000e';
do $$ begin
  if (select count(*) from orders) <> 1 then raise exception 'FAIL: rider cannot see job'; end if;
end $$;
set test.uid = '00000000-0000-0000-0000-00000000000d';
select claim_order(:'oid') as first_claim \gset
set test.uid = '00000000-0000-0000-0000-00000000000e';
select claim_order(:'oid') as second_claim \gset
\if :first_claim
\else
  \echo FAIL first claim
  select 1/0;
\endif
\if :second_claim
  \echo FAIL second claim won
  select 1/0;
\endif
-- second rider can no longer see the job
do $$ begin
  if (select count(*) from orders) <> 0 then raise exception 'FAIL: claimed job still visible'; end if;
end $$;

set test.uid = '00000000-0000-0000-0000-00000000000b';
select set_order_status(:'oid', 'cooking');
select set_order_status(:'oid', 'ready');
set test.uid = '00000000-0000-0000-0000-00000000000d';
select set_order_status(:'oid', 'picked_up');
select set_order_status(:'oid', 'delivering');
select set_order_status(:'oid', 'completed');

do $$ begin
  if (select status from orders) <> 'completed' or (select food_payment_status from orders) <> 'confirmed' then
    raise exception 'FAIL: final state wrong';
  end if;
end $$;
\echo ALL DB FLOW CHECKS PASSED

-- ---------------------------------------------------------------- map (0002)
set test.uid = '00000000-0000-0000-0000-00000000000c';
select place_order('10000000-0000-0000-0000-000000000001',
  '[{"menu_item_id":"30000000-0000-0000-0000-000000000001","qty":1}]',
  'delivery', '20000000-0000-0000-0000-000000000001', 'cash', 'cash', 'map test') as mid \gset
select set_order_dropoff(:'mid', 13.75, 100.5);
-- another customer cannot move the pin
set test.uid = '00000000-0000-0000-0000-00000000000b';
do $$ begin
  perform set_order_dropoff((select id from orders where address_note = 'map test'), 1, 1);
  raise exception 'FAIL: non-owner set dropoff';
exception when others then
  if sqlerrm not like 'order not found%' then raise; end if;
end $$;
select set_order_status(:'mid', 'accepted');
select set_order_status(:'mid', 'ready');
-- unassigned rider cannot report location
set test.uid = '00000000-0000-0000-0000-00000000000d';
do $$ begin
  perform update_rider_location((select id from orders where address_note = 'map test'), 13.7, 100.4);
  raise exception 'FAIL: unassigned rider updated location';
exception when others then
  if sqlerrm not like 'not delivering%' then raise; end if;
end $$;
select claim_order(:'mid');
select update_rider_location(:'mid', 13.7, 100.4);
set test.uid = '00000000-0000-0000-0000-00000000000c';
do $$ begin
  if (select rider_lat from orders where address_note = 'map test') <> 13.7
     or (select dropoff_lat from orders where address_note = 'map test') <> 13.75 then
    raise exception 'FAIL: map fields not visible to customer';
  end if;
end $$;
\echo ALL MAP CHECKS PASSED

-- ---------------------------------------------------------------- shop applications (0003)
set test.uid = '00000000-0000-0000-0000-00000000000c';
-- cannot sneak in an approved or live shop
do $$ begin
  insert into shops (owner_id, name, promptpay_id, status, is_active)
    values (auth.uid(), 'fake', '0812345678', 'approved', true);
  raise exception 'FAIL: member created a live shop';
exception when others then
  if sqlerrm not like '%row-level security%' then raise; end if;
end $$;
insert into shops (id, owner_id, name, promptpay_id, status, is_active, category, lat, lng, submitted_at)
  values ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000c',
          'ส้มตำป้าแดง', '0811111111', 'pending', false, 'ส้มตำ / อาหารอีสาน', 16.9, 102.9, now());
do $$ begin
  update shops set status = 'approved' where id = '10000000-0000-0000-0000-000000000002';
  raise exception 'FAIL: member approved own shop';
exception when others then
  if sqlerrm not like 'only admin can approve%' then raise; end if;
end $$;
do $$ begin
  update shops set is_open = true where id = '10000000-0000-0000-0000-000000000002';
  raise exception 'FAIL: pending shop opened';
exception when others then
  if sqlerrm not like 'shop is not approved%' then raise; end if;
end $$;
do $$ begin
  perform review_shop('10000000-0000-0000-0000-000000000002', true, null);
  raise exception 'FAIL: member reviewed a shop';
exception when others then
  if sqlerrm not like 'only admin can review%' then raise; end if;
end $$;
-- other members cannot see the application
set test.uid = '00000000-0000-0000-0000-00000000000e';
do $$ begin
  if exists (select 1 from shops where id = '10000000-0000-0000-0000-000000000002') then
    raise exception 'FAIL: pending shop visible to others';
  end if;
end $$;
-- admin rejects with a reason; member fixes and resubmits
set test.uid = '00000000-0000-0000-0000-00000000000a';
select review_shop('10000000-0000-0000-0000-000000000002', false, 'ขอรูปหน้าร้านชัดๆ');
set test.uid = '00000000-0000-0000-0000-00000000000c';
do $$ begin
  if (select review_note from shops where id = '10000000-0000-0000-0000-000000000002') <> 'ขอรูปหน้าร้านชัดๆ' then
    raise exception 'FAIL: member cannot read rejection reason';
  end if;
end $$;
update shops set cover_url = 'new.jpg', status = 'pending' where id = '10000000-0000-0000-0000-000000000002';
-- admin approves: shop goes live and the member becomes a shop owner
set test.uid = '00000000-0000-0000-0000-00000000000a';
select review_shop('10000000-0000-0000-0000-000000000002', true, null);
set test.uid = '00000000-0000-0000-0000-00000000000c';
update shops set is_open = true where id = '10000000-0000-0000-0000-000000000002';
do $$ begin
  if (select role from profiles where id = auth.uid()) <> 'shop_owner'
     or not (select is_active and status = 'approved' and review_note is null
               from shops where id = '10000000-0000-0000-0000-000000000002') then
    raise exception 'FAIL: approval did not take effect';
  end if;
end $$;
\echo ALL SHOP APPLICATION CHECKS PASSED

-- the app names these foreign keys in its PostgREST embeds (Api.members, Api.shopForReview)
reset role;
do $$ begin
  if (select count(*) from pg_constraint where conname in ('shops_owner_id_fkey', 'riders_id_fkey')) <> 2 then
    raise exception 'FAIL: foreign key names used by the app changed';
  end if;
end $$;
\echo ALL EMBED NAME CHECKS PASSED
