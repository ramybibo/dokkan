-- DOKKAN | Phase 1 | 03 operations schema (employees, shifts, purchases, sales, expenses)
-- Money columns are numeric(12,2) in EGP. Financial tables are READ-ONLY for clients:
-- all writes arrive through server-side transactional functions in Phase 2.

create type public.payment_method as enum ('cash', 'card', 'wallet', 'instapay');
create type public.sale_status as enum ('completed', 'voided');

create table public.employees (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  member_user_id uuid,
  full_name text not null check (char_length(btrim(full_name)) between 1 and 120),
  phone text check (char_length(phone) <= 20),
  job_title text check (char_length(job_title) <= 60),
  hired_on date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, id),
  foreign key (store_id, member_user_id) references public.store_members (store_id, user_id)
);

create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  opened_by uuid not null,
  opened_at timestamptz not null default now(),
  opening_cash numeric(12, 2) not null default 0 check (opening_cash >= 0),
  closed_by uuid,
  closed_at timestamptz,
  counted_cash numeric(12, 2) check (counted_cash >= 0),
  expected_cash numeric(12, 2),
  note text check (char_length(note) <= 500),
  unique (store_id, id),
  foreign key (store_id, opened_by) references public.store_members (store_id, user_id),
  foreign key (store_id, closed_by) references public.store_members (store_id, user_id),
  check ((closed_at is null and closed_by is null) or (closed_at is not null and closed_by is not null))
);
create unique index shifts_one_open_per_user_uq
  on public.shifts (store_id, opened_by) where closed_at is null;

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  supplier_id uuid,
  invoice_no text check (char_length(invoice_no) <= 60),
  purchased_on date not null default current_date,
  total numeric(12, 2) not null check (total >= 0),
  paid numeric(12, 2) not null default 0 check (paid >= 0),
  note text check (char_length(note) <= 500),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (store_id, id),
  check (paid <= total),
  foreign key (store_id, supplier_id) references public.suppliers (store_id, id)
);

create table public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  purchase_id uuid not null,
  variant_id uuid not null,
  quantity integer not null check (quantity > 0),
  unit_cost numeric(12, 2) not null check (unit_cost >= 0),
  foreign key (store_id, purchase_id) references public.purchases (store_id, id) on delete cascade,
  foreign key (store_id, variant_id) references public.product_variants (store_id, id)
);

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  receipt_no bigint not null,
  shift_id uuid,
  cashier_id uuid not null,
  status public.sale_status not null default 'completed',
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  discount numeric(12, 2) not null default 0 check (discount >= 0),
  total numeric(12, 2) not null check (total >= 0),
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  voided_at timestamptz,
  voided_by uuid,
  unique (store_id, id),
  unique (store_id, receipt_no),
  check (discount <= subtotal),
  check (total = subtotal - discount),
  foreign key (store_id, shift_id) references public.shifts (store_id, id),
  foreign key (store_id, cashier_id) references public.store_members (store_id, user_id),
  foreign key (store_id, voided_by) references public.store_members (store_id, user_id)
);
create index sales_store_created_idx on public.sales (store_id, created_at desc);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  sale_id uuid not null,
  variant_id uuid not null,
  product_name text not null,
  size text not null,
  color text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  line_total numeric(12, 2) not null,
  check (line_total = quantity * unit_price),
  foreign key (store_id, sale_id) references public.sales (store_id, id),
  foreign key (store_id, variant_id) references public.product_variants (store_id, id)
);

create table public.sale_payments (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  sale_id uuid not null,
  method public.payment_method not null,
  amount numeric(12, 2) not null check (amount > 0),
  reference text check (char_length(reference) <= 80),
  foreign key (store_id, sale_id) references public.sales (store_id, id)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  category text not null check (char_length(btrim(category)) between 1 and 60),
  amount numeric(12, 2) not null check (amount > 0),
  expense_date date not null default current_date,
  note text check (char_length(note) <= 500),
  shift_id uuid,
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (store_id, shift_id) references public.shifts (store_id, id)
);

-- Gap-free receipt numbering per store; touched only by server-side functions.
create table public.receipt_counters (
  store_id uuid primary key references public.stores (id) on delete cascade,
  last_receipt_no bigint not null default 0
);

create function private.init_store_counters()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.receipt_counters (store_id) values (new.id);
  return new;
end;
$$;
create trigger stores_init_counters after insert on public.stores
  for each row execute function private.init_store_counters();

-- --------------------------------------------------------------------- RLS
alter table public.employees enable row level security;
alter table public.shifts enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.sale_payments enable row level security;
alter table public.expenses enable row level security;
alter table public.receipt_counters enable row level security; -- no policies: clients get nothing

create policy employees_select on public.employees
  for select to authenticated
  using (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]));
create policy employees_insert on public.employees
  for insert to authenticated
  with check (private.has_store_role(store_id, array['owner']::public.member_role[]));
create policy employees_update on public.employees
  for update to authenticated
  using (private.has_store_role(store_id, array['owner']::public.member_role[]))
  with check (private.has_store_role(store_id, array['owner']::public.member_role[]));
create policy employees_delete on public.employees
  for delete to authenticated
  using (private.has_store_role(store_id, array['owner']::public.member_role[]));

-- A cashier sees only their own shifts and sales; owners/managers see all.
create policy shifts_select on public.shifts
  for select to authenticated
  using (
    private.has_store_role(store_id, array['owner', 'manager']::public.member_role[])
    or (private.is_store_member(store_id) and opened_by = (select auth.uid()))
  );

create policy purchases_select on public.purchases
  for select to authenticated
  using (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]));
create policy purchase_items_select on public.purchase_items
  for select to authenticated
  using (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]));

create policy sales_select on public.sales
  for select to authenticated
  using (
    private.has_store_role(store_id, array['owner', 'manager']::public.member_role[])
    or (private.is_store_member(store_id) and cashier_id = (select auth.uid()))
  );
-- Child rows inherit visibility from the parent sale (the sales policy applies inside the subquery).
create policy sale_items_select on public.sale_items
  for select to authenticated
  using (exists (
    select 1 from public.sales s where s.store_id = sale_items.store_id and s.id = sale_items.sale_id));
create policy sale_payments_select on public.sale_payments
  for select to authenticated
  using (exists (
    select 1 from public.sales s where s.store_id = sale_payments.store_id and s.id = sale_payments.sale_id));

create policy expenses_select on public.expenses
  for select to authenticated
  using (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]));
create policy expenses_insert on public.expenses
  for insert to authenticated
  with check (private.has_store_role(store_id, array['owner', 'manager']::public.member_role[]));
create policy expenses_update on public.expenses
  for update to authenticated
  using (private.has_store_role(store_id, array['owner']::public.member_role[]))
  with check (private.has_store_role(store_id, array['owner']::public.member_role[]));
create policy expenses_delete on public.expenses
  for delete to authenticated
  using (private.has_store_role(store_id, array['owner']::public.member_role[]));
