-- DOKKAN | Phase 1 | 02 catalog and stock
-- Tenant isolation is enforced twice: by RLS, and by composite (store_id, id) foreign keys
-- so a row can never reference a parent that belongs to a different store.

create type public.product_gender as enum ('men', 'women', 'kids', 'unisex');
create type public.stock_reason as enum
  ('opening', 'purchase', 'sale', 'sale_void', 'return', 'adjustment');

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  created_at timestamptz not null default now(),
  unique (store_id, id)
);
create unique index categories_store_name_uq on public.categories (store_id, lower(name));

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  created_at timestamptz not null default now(),
  unique (store_id, id)
);
create unique index brands_store_name_uq on public.brands (store_id, lower(name));

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  phone text check (char_length(phone) <= 20),
  address text check (char_length(address) <= 300),
  notes text check (char_length(notes) <= 1000),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 160),
  model_code text check (char_length(model_code) <= 60),
  brand_id uuid,
  category_id uuid,
  gender public.product_gender not null default 'unisex',
  description text check (char_length(description) <= 2000),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, id),
  foreign key (store_id, brand_id) references public.brands (store_id, id),
  foreign key (store_id, category_id) references public.categories (store_id, id)
);
create trigger products_touch before update on public.products
  for each row execute function private.touch_updated_at();

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  product_id uuid not null,
  size text not null check (char_length(btrim(size)) between 1 and 10),
  color text not null check (char_length(btrim(color)) between 1 and 40),
  sku text check (char_length(sku) <= 60),
  barcode text check (char_length(barcode) between 4 and 64),
  sale_price numeric(12, 2) not null check (sale_price >= 0),
  reorder_level integer not null default 0 check (reorder_level >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, id),
  unique (store_id, product_id, size, color),
  foreign key (store_id, product_id) references public.products (store_id, id) on delete cascade
);
create unique index variants_store_barcode_uq
  on public.product_variants (store_id, barcode) where barcode is not null;
create trigger variants_touch before update on public.product_variants
  for each row execute function private.touch_updated_at();

-- Cost is kept apart from the sellable variant so cashiers can never read it.
create table public.variant_costs (
  store_id uuid not null,
  variant_id uuid not null,
  cost_price numeric(12, 2) not null default 0 check (cost_price >= 0),
  primary key (store_id, variant_id),
  foreign key (store_id, variant_id) references public.product_variants (store_id, id) on delete cascade
);

-- Current on-hand quantity. Cannot go negative (no overselling at the database level).
-- Clients may only read it; stock changes happen in server-side functions (Phase 2).
create table public.variant_stock (
  store_id uuid not null,
  variant_id uuid not null,
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (store_id, variant_id),
  foreign key (store_id, variant_id) references public.product_variants (store_id, id) on delete cascade
);

create function private.init_variant_rows()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.variant_costs (store_id, variant_id) values (new.store_id, new.id);
  insert into public.variant_stock (store_id, variant_id) values (new.store_id, new.id);
  return new;
end;
$$;
create trigger variants_init_rows after insert on public.product_variants
  for each row execute function private.init_variant_rows();

-- Append-only stock ledger.
create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  variant_id uuid not null,
  qty_delta integer not null check (qty_delta <> 0),
  reason public.stock_reason not null,
  ref_type text check (char_length(ref_type) <= 30),
  ref_id uuid,
  note text check (char_length(note) <= 300),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (store_id, variant_id) references public.product_variants (store_id, id)
);
create index stock_movements_variant_idx on public.stock_movements (store_id, variant_id, created_at desc);

create function private.forbid_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% on % is not allowed (append-only)', tg_op, tg_table_name using errcode = '42501';
end;
$$;
create trigger stock_movements_immutable before update or delete on public.stock_movements
  for each row execute function private.forbid_mutation();

-- --------------------------------------------------------------------- RLS
alter table public.categories enable row level security;
alter table public.brands enable row level security;
alter table public.suppliers enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.variant_costs enable row level security;
alter table public.variant_stock enable row level security;
alter table public.stock_movements enable row level security;

-- Catalog: every active member reads; owners/managers write.
do $$
declare
  t text;
begin
  foreach t in array array['categories', 'brands', 'suppliers', 'products', 'product_variants'] loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (private.is_store_member(store_id))',
      t || '_select', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (private.has_store_role(store_id, array[''owner'',''manager'']::public.member_role[]))',
      t || '_insert', t);
    execute format(
      'create policy %I on public.%I for update to authenticated using (private.has_store_role(store_id, array[''owner'',''manager'']::public.member_role[])) with check (private.has_store_role(store_id, array[''owner'',''manager'']::public.member_role[]))',
      t || '_update', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated using (private.has_store_role(store_id, array[''owner'',''manager'']::public.member_role[]))',
      t || '_delete', t);
  end loop;
end;
$$;

create policy variant_costs_select on public.variant_costs
  for select to authenticated
  using (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]));
create policy variant_costs_update on public.variant_costs
  for update to authenticated
  using (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]))
  with check (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]));

-- Cashiers need on-hand quantities at the till.
create policy variant_stock_select on public.variant_stock
  for select to authenticated
  using (private.is_store_member(store_id));

create policy stock_movements_select on public.stock_movements
  for select to authenticated
  using (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]));
