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
