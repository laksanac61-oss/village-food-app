-- Remember what each member picked at sign-up (customer, shop or rider) on their profile,
-- so the admin can see people who chose "rider" before they send their documents.
-- Safe to run more than once.

alter table profiles add column if not exists signup_as text not null default 'customer';

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, phone, signup_as)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'phone',
          coalesce(nullif(new.raw_user_meta_data->>'signup_as', ''), 'customer'));
  return new;
end;
$$;

-- Members who signed up before this change
update profiles p set signup_as = u.raw_user_meta_data->>'signup_as'
  from auth.users u
 where u.id = p.id
   and coalesce(u.raw_user_meta_data->>'signup_as', '') <> ''
   and p.signup_as is distinct from u.raw_user_meta_data->>'signup_as';

notify pgrst, 'reload schema';
