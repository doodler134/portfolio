-- Doodle Portfolio: Supabase setup
-- Run this once in Supabase SQL Editor.
-- IMPORTANT: do NOT put a service_role key into the website.

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

-- Create the bucket. It is public for portfolio viewing, but writes are restricted.
insert into storage.buckets (id, name, public)
values ('portfolio-media', 'portfolio-media', true)
on conflict (id) do update set public = true;

drop policy if exists "Public can read portfolio media" on storage.objects;
create policy "Public can read portfolio media"
on storage.objects
for select
to public
using (bucket_id = 'portfolio-media');

drop policy if exists "Owner can upload portfolio media" on storage.objects;
create policy "Owner can upload portfolio media"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'portfolio-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Owner can update portfolio media" on storage.objects;
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

drop policy if exists "Owner can delete portfolio media" on storage.objects;
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
