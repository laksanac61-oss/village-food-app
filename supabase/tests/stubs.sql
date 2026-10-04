-- Minimal stand-ins for Supabase's auth/storage schemas so the migration
-- can be tested on plain Postgres. Not used in production.
create schema auth;
create table auth.users (id uuid primary key, raw_user_meta_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;
create schema storage;
create table storage.buckets (id text primary key, name text, public boolean,
  file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects (id uuid default gen_random_uuid(), bucket_id text, name text);
create function storage.foldername(name text) returns text[] language sql as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
create publication supabase_realtime;
-- pg_net stand-in: records the calls instead of sending them
create schema net;
create table net.calls (id bigserial, url text, body jsonb);
create function net.http_post(url text, body jsonb default '{}', params jsonb default '{}',
  headers jsonb default '{}', timeout_milliseconds int default 5000) returns bigint
language sql as $$ insert into net.calls (url, body) values (url, body) returning id $$;
grant usage on schema net to public;
grant insert, select on net.calls to public;
grant usage on sequence net.calls_id_seq to public;
