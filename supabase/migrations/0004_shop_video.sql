-- Approved shops add a short intro video that customers can watch.
-- A shop can change its video a limited number of times a day (Thai time);
-- the admin can raise a shop's limit later, e.g. as a paid extra. Safe to run more than once.

alter table shops
  add column if not exists video_url text,
  add column if not exists video_changes_per_day int not null default 2;

create table if not exists shop_video_changes (
  id bigint generated always as identity primary key,
  shop_id uuid not null references shops(id) on delete cascade,
  changed_at timestamptz not null default now()
);
alter table shop_video_changes enable row level security;
drop policy if exists "shop reads own video changes" on shop_video_changes;
create policy "shop reads own video changes" on shop_video_changes for select
  using (owns_shop(shop_id) or is_admin());

-- videos/<owner uid>/<time>.mp4, public so customers can stream them.
-- 50 MB is the largest single file Supabase's free plan accepts.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('videos', 'videos', true, 52428800, array['video/mp4', 'video/quicktime', 'video/webm'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "shop owner uploads videos" on storage.objects;
create policy "shop owner uploads videos" on storage.objects for insert
  with check (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);
-- Removing a file needs read and delete on it: owners clear out their old videos.
drop policy if exists "shop owner reads own videos" on storage.objects;
create policy "shop owner reads own videos" on storage.objects for select
  using (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "shop owner deletes own videos" on storage.objects;
create policy "shop owner deletes own videos" on storage.objects for delete
  using (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);

-- The video and its daily limit change only through set_shop_video (or by the admin).
create or replace function guard_shop_video() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if is_admin() or auth.uid() is null or current_setting('app.setting_shop_video', true) = 'on' then
    return new;
  end if;
  if new.video_url is distinct from old.video_url
     or new.video_changes_per_day is distinct from old.video_changes_per_day then
    raise exception 'use set_shop_video to change the shop video';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_shop_video on shops;
create trigger guard_shop_video before update on shops
  for each row execute function guard_shop_video();

-- Sets (or with null, removes) the shop's video. Returns how many changes are left today.
create or replace function set_shop_video(p_shop_id uuid, p_url text) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_limit int;
  v_used int;
  v_today timestamptz := date_trunc('day', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok';
begin
  if not (owns_shop(p_shop_id) or is_admin()) then
    raise exception 'not your shop';
  end if;
  select video_changes_per_day into v_limit from shops where id = p_shop_id and status = 'approved';
  if v_limit is null then
    raise exception 'ร้านต้องได้รับอนุมัติก่อนจึงเพิ่มวิดีโอได้';
  end if;
  select count(*) into v_used from shop_video_changes where shop_id = p_shop_id and changed_at >= v_today;
  if p_url is not null then
    -- only a file the owner uploaded to this project's videos bucket
    if p_url not like '%/storage/v1/object/public/videos/'
         || (select owner_id from shops where id = p_shop_id)::text || '/%' then
      raise exception 'invalid video address';
    end if;
    if v_used >= v_limit and not is_admin() then
      raise exception 'วันนี้เปลี่ยนวิดีโอครบ % ครั้งแล้ว เปลี่ยนได้อีกครั้งพรุ่งนี้', v_limit;
    end if;
    insert into shop_video_changes (shop_id) values (p_shop_id);
    v_used := v_used + 1;
  end if;
  perform set_config('app.setting_shop_video', 'on', true);
  update shops set video_url = p_url where id = p_shop_id;
  perform set_config('app.setting_shop_video', 'off', true);
  return greatest(v_limit - v_used, 0);
end;
$$;

notify pgrst, 'reload schema';
