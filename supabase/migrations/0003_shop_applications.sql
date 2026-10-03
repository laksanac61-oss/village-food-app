-- Members apply to open a shop from the app; the admin reviews and approves.
-- Safe to run more than once.
-- Shops the admin created before this migration count as approved.

do $$ begin
  create type shop_status as enum ('pending', 'approved', 'rejected');
exception when duplicate_object then null;
end $$;

alter table shops
  add column if not exists status shop_status not null default 'approved',
  add column if not exists review_note text,            -- admin's reason when rejecting
  add column if not exists category text,               -- type of food, e.g. ก๋วยเตี๋ยว
  add column if not exists address text,                -- house number, soi, landmark
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists cover_url text,              -- storefront photo (image_url stays the logo)
  add column if not exists opening_hours text,
  add column if not exists submitted_at timestamptz;

-- A member sends an application: always pending and hidden until approved.
drop policy if exists "member applies for shop" on shops;
create policy "member applies for shop" on shops for insert
  with check (owner_id = auth.uid() and status = 'pending' and not is_active and not is_open);

-- Owners may edit their application and resubmit it after a rejection,
-- but only the admin approves, rejects or activates a shop.
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
    if new.status is distinct from old.status
       and not (old.status = 'rejected' and new.status = 'pending') then
      raise exception 'only admin can approve a shop';
    end if;
    if new.review_note is distinct from old.review_note then
      raise exception 'only admin can write the review note';
    end if;
    if new.is_open and new.status <> 'approved' then
      raise exception 'shop is not approved yet';
    end if;
  end if;
  return new;
end;
$$;

-- Admin approves (shop goes live, member becomes a shop owner) or rejects with a reason.
create or replace function review_shop(p_shop_id uuid, p_approve boolean, p_note text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
begin
  if not is_admin() then raise exception 'only admin can review shops'; end if;
  update shops
     set status = case when p_approve then 'approved' else 'rejected' end::shop_status,
         is_active = p_approve,
         is_open = false,
         review_note = case when p_approve then null else nullif(trim(p_note), '') end
   where id = p_shop_id
  returning owner_id into v_owner;
  if v_owner is null then raise exception 'shop not found'; end if;
  if p_approve then
    update profiles set role = 'shop_owner' where id = v_owner and role = 'customer';
  end if;
end;
$$;

-- Make the API see the new columns straight away.
notify pgrst, 'reload schema';
