-- Grupee production schema
create extension if not exists "pgcrypto";
create type user_role as enum ('investor','admin');
create type pool_status as enum ('draft','open','closing','fully_funded','acquired','closed');
create type membership_status as enum ('pending','active','cancelled','exited');

create table profiles(id uuid primary key references auth.users(id) on delete cascade, full_name text not null, avatar_url text, role user_role not null default 'investor', deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table properties(id uuid primary key default gen_random_uuid(), owner_id uuid references profiles(id), title text not null, description text, address text, city text, country text, latitude double precision, longitude double precision, images text[] default '{}', documents text[] default '{}', deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table pools(id uuid primary key default gen_random_uuid(), property_id uuid references properties(id), title text not null, slug text unique not null, description text, status pool_status not null default 'draft', min_contribution bigint not null check(min_contribution>=0), target_amount bigint not null check(target_amount>0), raised_amount bigint not null default 0 check(raised_amount>=0 and raised_amount<=target_amount), expected_return text, location text, city text, images text[] default '{}', documents text[] default '{}', published_at timestamptz, deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table memberships(id uuid primary key default gen_random_uuid(), user_id uuid not null references profiles(id), pool_id uuid not null references pools(id), amount bigint not null check(amount>0), share_percent numeric(12,8) not null check(share_percent>=0 and share_percent<=100), status membership_status not null default 'pending', created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(user_id,pool_id));
create table transactions(id uuid primary key default gen_random_uuid(), user_id uuid not null references profiles(id), membership_id uuid references memberships(id), pool_id uuid references pools(id), kind text not null, amount bigint not null, status text not null default 'pending', provider_reference text, created_at timestamptz not null default now());
create table enquiries(id uuid primary key default gen_random_uuid(), type text not null default 'contact', name text not null, email text not null, message text, property_location text, status text not null default 'new', deleted_at timestamptz, created_at timestamptz not null default now());
create table notifications(id uuid primary key default gen_random_uuid(), user_id uuid not null references profiles(id), title text not null, body text not null, read_at timestamptz, created_at timestamptz not null default now());
create table ai_logs(id uuid primary key default gen_random_uuid(), user_id uuid references profiles(id), capability text not null, input text, output text, status text not null, created_at timestamptz not null default now());
create table automation_logs(id uuid primary key default gen_random_uuid(), workflow text not null, entity_type text, entity_id uuid, status text not null, payload jsonb, error text, created_at timestamptz not null default now());

create index idx_pools_status on pools(status) where deleted_at is null;
create index idx_pools_city on pools(city) where deleted_at is null;
create index idx_memberships_user on memberships(user_id);
create index idx_memberships_pool on memberships(pool_id);
create index idx_notifications_user on notifications(user_id, created_at desc);

alter table profiles enable row level security;
alter table properties enable row level security;
alter table pools enable row level security;
alter table memberships enable row level security;
alter table transactions enable row level security;
alter table enquiries enable row level security;
alter table notifications enable row level security;
alter table ai_logs enable row level security;
alter table automation_logs enable row level security;

create policy pools_public_read on pools for select using (status!='draft' and deleted_at is null);
create policy profiles_self_read on profiles for select using (auth.uid()=id);
create policy profiles_self_update on profiles for update using (auth.uid()=id);
create policy memberships_self_read on memberships for select using (auth.uid()=user_id);
create policy memberships_self_write on memberships for insert with check (auth.uid()=user_id);
create policy transactions_self_read on transactions for select using (auth.uid()=user_id);
create policy notifications_self_read on notifications for select using (auth.uid()=user_id);
create policy enquiries_insert_public on enquiries for insert with check (true);

create function is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from profiles where id=auth.uid() and role='admin')$$;
create policy admin_all_profiles on profiles for all using (is_admin()) with check (is_admin());
create policy admin_all_pools on pools for all using (is_admin()) with check (is_admin());
create policy admin_all_memberships on memberships for all using (is_admin()) with check (is_admin());
create policy admin_all_enquiries on enquiries for all using (is_admin()) with check (is_admin());
create policy admin_all_notifications on notifications for all using (is_admin()) with check (is_admin());
create policy admin_all_automation on automation_logs for all using (is_admin()) with check (is_admin());

-- Keep investor/admin profile rows synchronized with new Supabase Auth users.
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
    set full_name = excluded.full_name,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
