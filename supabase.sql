-- Doodle Portfolio: secure Supabase setup
-- Run this once in Supabase SQL Editor.
-- This version keeps Storage PRIVATE. Public visitors never get a public Storage URL.
-- The website uses the Edge Function in supabase/functions/portfolio-media-url to issue short-lived signed URLs.

create table if not exists public.portfolio_state (
  id bigint primary key default 1 check (id = 1),
  owner_id uuid references auth.users(id) on delete set null,
  title text not null default 'POSTERS',
  description text not null default '',
  theme text not null default 'dark',
  settings jsonb not null default '{}'::jsonb,
  items jsonb not null default '[]'::jsonb,
  bg_path text,
  updated_at timestamptz not null default now()
);

alter table public.portfolio_state enable row level security;

drop policy if exists "Public can read portfolio" on public.portfolio_state;
create policy "Public can read portfolio"
on public.portfolio_state
for select
to anon, authenticated
using (true);

drop policy if exists "Owner can insert portfolio" on public.portfolio_state;
create policy "Owner can insert portfolio"
on public.portfolio_state
for insert
to authenticated
with check (auth.uid() = owner_id);

drop policy if exists "Owner can update portfolio" on public.portfolio_state;
create policy "Owner can update portfolio"
on public.portfolio_state
for update
to authenticated
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

-- PRIVATE bucket: direct /storage/v1/object/public/... URLs will not work.
insert into storage.buckets (id, name, public)
values ('portfolio-media', 'portfolio-media', false)
on conflict (id) do update set public = false;

-- Remove any old public-read policy from the previous version.
drop policy if exists "Public can read portfolio media" on storage.objects;
drop policy if exists "Owner can read portfolio media" on storage.objects;
drop policy if exists "Owner can upload portfolio media" on storage.objects;
drop policy if exists "Owner can update portfolio media" on storage.objects;
drop policy if exists "Owner can delete portfolio media" on storage.objects;

-- Only the owner can directly read/list the files. Public visitors receive short-lived signed URLs from the Edge Function.
create policy "Owner can read portfolio media"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'portfolio-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Owner can upload portfolio media"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'portfolio-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Owner can update portfolio media"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'portfolio-media'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'portfolio-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Owner can delete portfolio media"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'portfolio-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- After creating your editor account in Authentication > Users,
-- disable public sign-ups in Authentication settings.
