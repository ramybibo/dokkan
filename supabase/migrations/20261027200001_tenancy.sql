-- DOKKAN | Phase 1 | 01 tenancy core
-- Currency is EGP everywhere, permanently. There is deliberately no currency column anywhere.
-- Every tenant table carries store_id; RLS decides access by store membership + role.

create schema if not exists private;
grant usage on schema private to authenticated;

create type public.member_role as enum ('owner', 'manager', 'cashier');
create type public.member_status as enum ('active', 'suspended');

create function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '' check (char_length(full_name) <= 120),
  phone text check (phone is null or phone ~ '^[0-9+() -]{6,20}$'),
  locale text not null default 'ar' check (locale in ('ar', 'en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'full_name', ''), 120))
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- ------------------------------------------------------------------ stores
create table public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  phone text check (phone is null or phone ~ '^[0-9+() -]{6,20}$'),
  governorate text check (char_length(governorate) <= 60),
  city text check (char_length(city) <= 80),
  address text check (char_length(address) <= 300),
  tax_registration_no text check (char_length(tax_registration_no) <= 40),
  receipt_footer text check (char_length(receipt_footer) <= 300),
  receipt_paper_mm smallint not null default 80 check (receipt_paper_mm in (58, 80)),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger stores_touch before update on public.stores
  for each row execute function private.touch_updated_at();

-- ----------------------------------------------------------- store_members
create table public.store_members (
  store_id uuid not null references public.stores (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.member_role not null,
  status public.member_status not null default 'active',
  created_at timestamptz not null default now(),
  primary key (store_id, user_id)
);
create index store_members_user_idx on public.store_members (user_id);

-- ----------------------------------------------------- RLS helper functions
-- SECURITY DEFINER so policies never recurse into store_members' own RLS.
-- They live in the "private" schema, which the Data API does not expose.
create function private.is_store_member(p_store uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.store_members m
    where m.store_id = p_store
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;

create function private.has_store_role(p_store uuid, p_roles public.member_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.store_members m
    where m.store_id = p_store
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.role = any (p_roles)
  );
$$;

revoke all on function private.is_store_member(uuid) from public, anon;
revoke all on function private.has_store_role(uuid, public.member_role[]) from public, anon;
grant execute on function private.is_store_member(uuid) to authenticated;
grant execute on function private.has_store_role(uuid, public.member_role[]) to authenticated;

-- --------------------------------------------------------------------- RLS
alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.store_members enable row level security;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy stores_select_member on public.stores
  for select to authenticated
  using (private.is_store_member(id));

create policy stores_update_admin on public.stores
  for update to authenticated
  using (private.has_store_role(id, array['owner', 'manager']::public.member_role[]))
  with check (private.has_store_role(id, array['owner', 'manager']::public.member_role[]));

-- Members see themselves; owners/managers see the whole team.
-- No client INSERT/UPDATE/DELETE policies: team changes go through server-side functions.
create policy store_members_select on public.store_members
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.has_store_role(store_id, array['owner', 'manager']::public.member_role[])
  );

-- ---------------------------------------------------------- store onboarding
-- Atomic: creates the store and its first owner membership in one transaction.
create function public.create_store(
  p_name text,
  p_phone text default null,
  p_governorate text default null,
  p_city text default null,
  p_address text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_store uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if char_length(btrim(coalesce(p_name, ''))) < 2 then
    raise exception 'store name is too short' using errcode = '22023';
  end if;

  if (select count(*) from public.store_members
      where user_id = v_uid and role = 'owner') >= 5 then
    raise exception 'store limit reached' using errcode = 'P0001';
  end if;

  insert into public.stores (name, phone, governorate, city, address, created_by)
  values (btrim(p_name), nullif(btrim(p_phone), ''), nullif(btrim(p_governorate), ''),
          nullif(btrim(p_city), ''), nullif(btrim(p_address), ''), v_uid)
  returning id into v_store;

  insert into public.store_members (store_id, user_id, role)
  values (v_store, v_uid, 'owner');

  return v_store;
end;
$$;
