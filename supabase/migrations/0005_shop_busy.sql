-- A shop can say its delivery is running late (riders are tied up) for a while.
-- Customers see an orange "busy" tag and choose to wait, pick up, or not order. Safe to run more than once.

alter table shops add column if not exists busy_until timestamptz;  -- busy while now() < busy_until

-- How many approved riders are online right now, so checkout can warn when nobody can deliver.
-- Only the count is shared; who is online stays private.
create or replace function riders_online() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from riders where status = 'approved' and is_online;
$$;

notify pgrst, 'reload schema';
