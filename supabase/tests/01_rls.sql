-- RLS / isolation tests. Run with psql after the bootstrap and all migrations:
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/01_rls.sql
-- Everything runs inside one transaction that is rolled back at the end.
\set ON_ERROR_STOP on
begin;

create schema tests;
create table tests.results (n serial, label text not null, ok boolean not null);

create function tests.check(p_label text, p_ok boolean) returns void
language sql as $$ insert into tests.results (label, ok) values (p_label, coalesce(p_ok, false)) $$;

-- Passes when the statement raises any error (permission denied, RLS violation, FK, check...).
create function tests.denied(p_label text, p_stmt text) returns void
language plpgsql as $$
begin
  begin
    execute p_stmt;
    insert into tests.results (label, ok) values (p_label, false);
  exception when others then
    insert into tests.results (label, ok) values (p_label, true);
  end;
end $$;

-- Passes when the statement succeeds and touches exactly p_expected rows.
create function tests.rows(p_label text, p_stmt text, p_expected int) returns void
language plpgsql as $$
declare n int;
begin
  execute p_stmt;
  get diagnostics n = row_count;
  insert into tests.results (label, ok) values (p_label, n = p_expected);
exception when others then
  insert into tests.results (label, ok) values (p_label || ' [error: ' || sqlerrm || ']', false);
end $$;

-- Passes when a SELECT returns exactly p_expected rows.
create function tests.count(p_label text, p_query text, p_expected int) returns void
language plpgsql as $$
declare n int;
begin
  execute 'select count(*) from (' || p_query || ') s' into n;
  insert into tests.results (label, ok) values (p_label, n = p_expected);
exception when others then
  insert into tests.results (label, ok) values (p_label || ' [error: ' || sqlerrm || ']', false);
end $$;

grant usage on schema tests to anon, authenticated;
grant all on tests.results to anon, authenticated;
grant usage on all sequences in schema tests to anon, authenticated;
grant execute on all functions in schema tests to anon, authenticated;

-- ------------------------------------------------------------ fixtures
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.test', '{"full_name":"Alice"}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.test',   '{"full_name":"Bob"}'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.test', '{"full_name":"Carol"}');

select tests.check('signup trigger created a profile with the metadata name',
  (select full_name from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000001') = 'Alice');

-- ------------------------------------------------- anonymous visitors
set local role anon;
select tests.denied('anon cannot read stores', 'select * from public.stores');
select tests.denied('anon cannot read products', 'select * from public.products');
select tests.denied('anon cannot call create_store', $$select public.create_store('Anon Shop')$$);
select tests.denied('anon cannot call RLS helper in private schema',
  $$select private.is_store_member('aaaaaaaa-0000-0000-0000-000000000001')$$);
reset role;

-- --------------------------------------------- signed-in but no claims
set local role authenticated;
select tests.denied('create_store rejects a caller with no user id', $$select public.create_store('Ghost Shop')$$);
reset role;

-- --------------------------------------------------------- onboarding
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select public.create_store('Alice Shoes', '01000000001', 'Cairo', 'Nasr City', null) as store_a \gset
select tests.denied('create_store rejects a 1-character name', $$select public.create_store('x')$$);
select tests.count('alice sees exactly her own store', 'select 1 from public.stores', 1);
select tests.count('alice is owner of her store',
  format('select 1 from public.store_members where store_id = %L and user_id = auth.uid() and role = ''owner''', :'store_a'), 1);
reset role;

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select public.create_store('Bob Footwear') as store_b \gset
select tests.count('bob sees exactly his own store', 'select 1 from public.stores', 1);
select tests.count('bob cannot see alice''s store', format('select 1 from public.stores where id = %L', :'store_a'), 0);
select tests.count('bob cannot see alice''s membership rows', format('select 1 from public.store_members where store_id = %L', :'store_a'), 0);
reset role;

select tests.check('receipt counter row exists for both stores',
  (select count(*) from public.receipt_counters) = 2);

-- carol becomes a cashier in alice's store (done by the server, never by a client)
insert into public.store_members (store_id, user_id, role)
values (:'store_a', 'cccccccc-0000-0000-0000-000000000003', 'cashier');

-- ------------------------------------------------- catalog as the owner
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
insert into public.brands (store_id, name) values (:'store_a', 'Nike') returning id as brand_a \gset
insert into public.products (store_id, name, brand_id) values (:'store_a', 'Runner', :'brand_a') returning id as prod_a \gset
insert into public.product_variants (store_id, product_id, size, color, sale_price)
  values (:'store_a', :'prod_a', '42', 'Black', 1500.00) returning id as var_a \gset
select tests.count('owner reads her variant', 'select 1 from public.product_variants', 1);
select tests.count('stock row auto-created', 'select 1 from public.variant_stock', 1);
select tests.count('owner can read cost rows', 'select 1 from public.variant_costs', 1);
select tests.rows('owner updates a variant price',
  format('update public.product_variants set sale_price = 1600 where id = %L', :'var_a'), 1);
select tests.denied('duplicate size+color for the same product is rejected',
  format('insert into public.product_variants (store_id, product_id, size, color, sale_price) values (%L,%L,''42'',''Black'',1)', :'store_a', :'prod_a'));
select tests.denied('negative price is rejected',
  format('insert into public.product_variants (store_id, product_id, size, color, sale_price) values (%L,%L,''43'',''Black'',-5)', :'store_a', :'prod_a'));
select tests.denied('owner cannot insert a product into another store',
  format('insert into public.products (store_id, name) values (%L, ''Intruder'')', :'store_b'));
select tests.denied('client cannot move a row to another store',
  format('update public.products set store_id = %L where id = %L', :'store_b', :'prod_a'));
reset role;

-- ---------------------------------------------------- bob attacks store A
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
insert into public.brands (store_id, name) values (:'store_b', 'Adidas') returning id as brand_b \gset
insert into public.products (store_id, name) values (:'store_b', 'Bob Boot') returning id as prod_b \gset
select tests.count('bob cannot read alice''s products', format('select 1 from public.products where id = %L', :'prod_a'), 0);
select tests.count('bob cannot read alice''s variants', 'select 1 from public.product_variants where store_id = ' || quote_literal(:'store_a'), 0);
select tests.count('bob cannot read alice''s stock', 'select 1 from public.variant_stock where store_id = ' || quote_literal(:'store_a'), 0);
select tests.count('bob cannot read alice''s costs', 'select 1 from public.variant_costs where store_id = ' || quote_literal(:'store_a'), 0);
select tests.rows('bob cannot update alice''s product (0 rows)',
  format('update public.products set name = ''hacked'' where id = %L', :'prod_a'), 0);
select tests.rows('bob cannot delete alice''s product (0 rows)',
  format('delete from public.products where id = %L', :'prod_a'), 0);
select tests.rows('bob cannot rename alice''s store (0 rows)',
  format('update public.stores set name = ''hacked'' where id = %L', :'store_a'), 0);
select tests.denied('bob cannot insert into alice''s store',
  format('insert into public.categories (store_id, name) values (%L, ''x'')', :'store_a'));
select tests.denied('bob cannot attach a variant of his store to alice''s product (composite FK)',
  format('insert into public.product_variants (store_id, product_id, size, color, sale_price) values (%L,%L,''40'',''Red'',10)', :'store_b', :'prod_a'));
reset role;

-- alice tries to reference bob's rows from her own store: composite FKs must stop it
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select tests.denied('alice cannot create a variant under bob''s product',
  format('insert into public.product_variants (store_id, product_id, size, color, sale_price) values (%L,%L,''40'',''Red'',10)', :'store_a', :'prod_b'));
select tests.denied('alice cannot use bob''s brand on her product',
  format('insert into public.products (store_id, name, brand_id) values (%L, ''Mix'', %L)', :'store_a', :'brand_b'));
reset role;

-- ----------------------------------------- stock ledger + financial rows
insert into public.stock_movements (store_id, variant_id, qty_delta, reason)
values (:'store_a', :'var_a', 10, 'opening');
update public.variant_stock set quantity = 10 where variant_id = :'var_a';

select tests.denied('stock ledger rows cannot be updated, even by the server',
  'update public.stock_movements set qty_delta = 99');
select tests.denied('stock ledger rows cannot be deleted, even by the server',
  'delete from public.stock_movements');
select tests.denied('on-hand stock cannot go negative',
  format('update public.variant_stock set quantity = -1 where variant_id = %L', :'var_a'));

insert into public.shifts (store_id, opened_by, opening_cash) values
  (:'store_a', 'aaaaaaaa-0000-0000-0000-000000000001', 100) returning id as shift_alice \gset
insert into public.shifts (store_id, opened_by, opening_cash) values
  (:'store_a', 'cccccccc-0000-0000-0000-000000000003', 50) returning id as shift_carol \gset
insert into public.sales (store_id, receipt_no, shift_id, cashier_id, subtotal, discount, total) values
  (:'store_a', 1, :'shift_alice', 'aaaaaaaa-0000-0000-0000-000000000001', 1600, 0, 1600) returning id as sale_alice \gset
insert into public.sales (store_id, receipt_no, shift_id, cashier_id, subtotal, discount, total) values
  (:'store_a', 2, :'shift_carol', 'cccccccc-0000-0000-0000-000000000003', 1600, 100, 1500) returning id as sale_carol \gset
insert into public.sale_items (store_id, sale_id, variant_id, product_name, size, color, quantity, unit_price, line_total)
  values (:'store_a', :'sale_carol', :'var_a', 'Runner', '42', 'Black', 1, 1600, 1600);
insert into public.sale_payments (store_id, sale_id, method, amount) values (:'store_a', :'sale_carol', 'cash', 1500);

select tests.denied('a sale cannot name a cashier who is not a member of that store',
  format('insert into public.sales (store_id, receipt_no, cashier_id, subtotal, total) values (%L, 3, ''bbbbbbbb-0000-0000-0000-000000000002'', 10, 10)', :'store_a'));
select tests.denied('a sale total must equal subtotal minus discount',
  format('insert into public.sales (store_id, receipt_no, cashier_id, subtotal, discount, total) values (%L, 4, ''aaaaaaaa-0000-0000-0000-000000000001'', 100, 10, 100)', :'store_a'));
select tests.denied('receipt numbers are unique per store',
  format('insert into public.sales (store_id, receipt_no, cashier_id, subtotal, total) values (%L, 1, ''aaaaaaaa-0000-0000-0000-000000000001'', 10, 10)', :'store_a'));
select tests.denied('only one open shift per user per store',
  format('insert into public.shifts (store_id, opened_by) values (%L, ''aaaaaaaa-0000-0000-0000-000000000001'')', :'store_a'));

-- owner: full visibility, but financial tables are read-only from the client
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select tests.count('owner sees all sales', 'select 1 from public.sales', 2);
select tests.count('owner sees all sale items', 'select 1 from public.sale_items', 1);
select tests.count('owner sees stock movements', 'select 1 from public.stock_movements', 1);
select tests.denied('client cannot insert a sale directly',
  format('insert into public.sales (store_id, receipt_no, cashier_id, subtotal, total) values (%L, 9, auth.uid(), 10, 10)', :'store_a'));
select tests.denied('client cannot insert a stock movement directly',
  format('insert into public.stock_movements (store_id, variant_id, qty_delta, reason) values (%L, %L, 5, ''adjustment'')', :'store_a', :'var_a'));
select tests.denied('client cannot change on-hand stock directly',
  format('update public.variant_stock set quantity = 999 where variant_id = %L', :'var_a'));
select tests.denied('client cannot write store_members (no self-promotion, no invites)',
  format('insert into public.store_members (store_id, user_id, role) values (%L, ''bbbbbbbb-0000-0000-0000-000000000002'', ''owner'')', :'store_a'));
select tests.denied('client cannot promote a member',
  format('update public.store_members set role = ''owner'' where store_id = %L', :'store_a'));
select tests.denied('client cannot insert a store directly (must use create_store)',
  $$insert into public.stores (name, created_by) values ('Direct', auth.uid())$$);
select tests.denied('client cannot touch receipt counters', 'select * from public.receipt_counters');
select tests.denied('client cannot delete a sale', 'delete from public.sales');
select tests.count('owner sees both team members', 'select 1 from public.store_members', 2);
reset role;

-- cashier: sells but cannot see costs, other people's sales, or write the catalog
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select tests.count('cashier reads the catalog', 'select 1 from public.products', 1);
select tests.count('cashier reads on-hand stock', 'select 1 from public.variant_stock', 1);
select tests.count('cashier cannot read cost prices', 'select 1 from public.variant_costs', 0);
select tests.count('cashier cannot read the stock ledger', 'select 1 from public.stock_movements', 0);
select tests.count('cashier sees only her own sales', 'select 1 from public.sales', 1);
select tests.count('cashier sees items only of her own sales', 'select 1 from public.sale_items', 1);
select tests.count('cashier sees only her own shift', 'select 1 from public.shifts', 1);
select tests.count('cashier cannot read purchases', 'select 1 from public.purchases', 0);
select tests.count('cashier cannot read expenses', 'select 1 from public.expenses', 0);
select tests.count('cashier cannot read employees', 'select 1 from public.employees', 0);
select tests.count('cashier sees only her own membership row', 'select 1 from public.store_members', 1);
select tests.denied('cashier cannot create products',
  format('insert into public.products (store_id, name) values (%L, ''x'')', :'store_a'));
select tests.denied('cashier cannot record expenses',
  format('insert into public.expenses (store_id, category, amount) values (%L, ''rent'', 10)', :'store_a'));
select tests.rows('cashier cannot rename the store (0 rows)',
  format('update public.stores set name = ''x'' where id = %L', :'store_a'), 0);
reset role;

-- suspended members lose access immediately
update public.store_members set status = 'suspended'
 where store_id = :'store_a' and user_id = 'cccccccc-0000-0000-0000-000000000003';
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select tests.count('suspended cashier sees no products', 'select 1 from public.products', 0);
select tests.count('suspended cashier sees no store', 'select 1 from public.stores', 0);
reset role;

-- ------------------------------------------------------------ profiles
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select tests.count('alice reads only her own profile', 'select 1 from public.profiles', 1);
select tests.rows('alice updates her own profile', $$update public.profiles set full_name = 'Alice A' where id = auth.uid()$$, 1);
select tests.rows('alice cannot update bob''s profile (0 rows)',
  $$update public.profiles set full_name = 'x' where id = 'bbbbbbbb-0000-0000-0000-000000000002'$$, 0);
select tests.denied('profiles cannot be inserted by clients',
  $$insert into public.profiles (id) values (gen_random_uuid())$$);
reset role;

-- ------------------------------------------------- structural guarantees
select tests.check('RLS is enabled on every public table',
  (select count(*) from pg_tables where schemaname = 'public' and not rowsecurity) = 0);
select tests.check('anon holds no table privileges in public',
  (select count(*) from information_schema.role_table_grants where grantee = 'anon' and table_schema = 'public') = 0);
select tests.check('anon can execute no function in public',
  (select count(*) from information_schema.routine_privileges where grantee = 'anon' and routine_schema = 'public') = 0);
select tests.check('PUBLIC can execute no function in public',
  (select count(*) from information_schema.routine_privileges where grantee = 'PUBLIC' and routine_schema = 'public') = 0);
select tests.check('no currency column exists anywhere (EGP is permanent)',
  (select count(*) from information_schema.columns where table_schema = 'public' and column_name ilike '%currency%') = 0);

-- ---------------------------------------------------------------- report
select case when ok then 'PASS' else 'FAIL' end as result, label from tests.results order by n;
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed from tests.results;
do $$
begin
  if exists (select 1 from tests.results where not ok) then
    raise exception 'RLS tests failed';
  end if;
end $$;
rollback;
