create extension if not exists pgcrypto;

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null unique,
  email text not null,
  display_name text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.app_users enable row level security;

create or replace function public.set_app_users_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_app_users_updated_at on public.app_users;

create trigger set_app_users_updated_at
before update on public.app_users
for each row
execute function public.set_app_users_updated_at();

drop policy if exists "App users can read their own record" on public.app_users;
create policy "App users can read their own record"
on public.app_users
for select
using ((auth.jwt() ->> 'sub') = clerk_user_id);

drop policy if exists "App users can insert their own record" on public.app_users;
create policy "App users can insert their own record"
on public.app_users
for insert
with check ((auth.jwt() ->> 'sub') = clerk_user_id);

drop policy if exists "App users can update their own record" on public.app_users;
create policy "App users can update their own record"
on public.app_users
for update
using ((auth.jwt() ->> 'sub') = clerk_user_id)
with check ((auth.jwt() ->> 'sub') = clerk_user_id);
