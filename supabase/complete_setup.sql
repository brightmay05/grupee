-- Run this entire script in Supabase: SQL Editor.
-- It is safe to rerun. It creates the Grupee schema, auth profile trigger,
-- login profile setup, policies, and sample pools.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type user_role as enum ('investor', 'admin');
  end if;
  if not exists (select 1 from pg_type where typname = 'pool_status') then
    create type pool_status as enum ('draft', 'open', 'closing', 'fully_funded', 'acquired', 'closed');
  end if;
  if not exists (select 1 from pg_type where typname = 'membership_status') then
    create type membership_status as enum ('pending', 'active', 'cancelled', 'exited');
  end if;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  avatar_url text,
  role user_role not null default 'investor',
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id),
  title text not null,
  description text,
  address text,
  city text,
  country text,
  latitude double precision,
  longitude double precision,
  images text[] not null default '{}',
  documents text[] not null default '{}',
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pools (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references public.properties(id),
  title text not null,
  slug text unique not null,
  description text,
  status pool_status not null default 'draft',
  min_contribution bigint not null check (min_contribution >= 0),
  target_amount bigint not null check (target_amount > 0),
  raised_amount bigint not null default 0 check (raised_amount >= 0 and raised_amount <= target_amount),
  expected_return text,
  location text,
  city text,
  images text[] not null default '{}',
  documents text[] not null default '{}',
  published_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  pool_id uuid not null references public.pools(id) on delete cascade,
  amount bigint not null check (amount > 0),
  share_percent numeric(12,8) not null check (share_percent >= 0 and share_percent <= 100),
  status membership_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, pool_id)
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  membership_id uuid references public.memberships(id) on delete set null,
  pool_id uuid references public.pools(id) on delete set null,
  kind text not null,
  amount bigint not null,
  status text not null default 'pending',
  provider_reference text,
  created_at timestamptz not null default now()
);

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'contact',
  name text not null,
  email text not null,
  message text,
  property_location text,
  status text not null default 'new',
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  capability text not null,
  input text,
  output text,
  status text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.automation_logs (
  id uuid primary key default gen_random_uuid(),
  workflow text not null,
  entity_type text,
  entity_id uuid,
  status text not null,
  payload jsonb,
  error text,
  created_at timestamptz not null default now()
);

create index if not exists idx_pools_status on public.pools(status) where deleted_at is null;
create index if not exists idx_pools_city on public.pools(city) where deleted_at is null;
create index if not exists idx_memberships_user on public.memberships(user_id);
create index if not exists idx_memberships_pool on public.memberships(pool_id);
create index if not exists idx_notifications_user on public.notifications(user_id, created_at desc);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    'investor'
  )
  on conflict (id) do update
    set full_name = coalesce(excluded.full_name, public.profiles.full_name),
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.properties enable row level security;
alter table public.pools enable row level security;
alter table public.memberships enable row level security;
alter table public.transactions enable row level security;
alter table public.enquiries enable row level security;
alter table public.notifications enable row level security;
alter table public.ai_logs enable row level security;
alter table public.automation_logs enable row level security;

drop policy if exists pools_public_read on public.pools;
drop policy if exists properties_public_read on public.properties;
drop policy if exists profiles_self_read on public.profiles;
drop policy if exists profiles_self_update on public.profiles;
drop policy if exists memberships_self_read on public.memberships;
drop policy if exists memberships_self_write on public.memberships;
drop policy if exists transactions_self_read on public.transactions;
drop policy if exists notifications_self_read on public.notifications;
drop policy if exists enquiries_insert_public on public.enquiries;
drop policy if exists admin_all_profiles on public.profiles;
drop policy if exists admin_all_pools on public.pools;
drop policy if exists admin_all_memberships on public.memberships;
drop policy if exists admin_all_enquiries on public.enquiries;
drop policy if exists admin_all_notifications on public.notifications;
drop policy if exists admin_all_automation on public.automation_logs;

create policy pools_public_read on public.pools
  for select using (status <> 'draft' and deleted_at is null);
create policy properties_public_read on public.properties
  for select using (deleted_at is null);
create policy profiles_self_read on public.profiles
  for select using (auth.uid() = id or public.is_admin());
create policy profiles_self_update on public.profiles
  for update using (auth.uid() = id or public.is_admin())
  with check (auth.uid() = id or public.is_admin());
create policy memberships_self_read on public.memberships
  for select using (auth.uid() = user_id or public.is_admin());
create policy memberships_self_write on public.memberships
  for insert with check (auth.uid() = user_id);
create policy transactions_self_read on public.transactions
  for select using (auth.uid() = user_id or public.is_admin());
create policy notifications_self_read on public.notifications
  for select using (auth.uid() = user_id or public.is_admin());
create policy enquiries_insert_public on public.enquiries
  for insert with check (true);
create policy admin_all_enquiries on public.enquiries
  for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all_pools on public.pools
  for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all_memberships on public.memberships
  for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all_notifications on public.notifications
  for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all_automation on public.automation_logs
  for all using (public.is_admin()) with check (public.is_admin());

-- Demo identities must be created in Supabase Dashboard > Authentication > Users.
-- This avoids direct writes to auth.users/auth.identities, which can break across
-- hosted Supabase Auth versions. The trigger above creates each public profile.

insert into public.pools (
  id, title, slug, status, min_contribution, target_amount,
  raised_amount, expected_return, location, city, description
)
values
  (gen_random_uuid(), 'Lekki Waterfront Residences', 'lekki-waterfront-residences', 'open', 250000, 120000000, 84600000, '12-18%', 'Lekki, Lagos', 'Lekki', 'A transparent residential property pool in Lekki.'),
  (gen_random_uuid(), 'Abuja Corporate Suites', 'abuja-corporate-suites', 'fully_funded', 500000, 200000000, 200000000, '10-14%', 'Wuse, Abuja', 'Abuja', 'A fully funded commercial property pool in Abuja.')
on conflict (slug) do update set
  title = excluded.title,
  status = excluded.status,
  min_contribution = excluded.min_contribution,
  target_amount = excluded.target_amount,
  raised_amount = excluded.raised_amount,
  expected_return = excluded.expected_return,
  location = excluded.location,
  city = excluded.city,
  description = excluded.description,
  updated_at = now();
