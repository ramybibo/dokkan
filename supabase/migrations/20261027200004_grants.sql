-- DOKKAN | Phase 1 | 04 least-privilege grants
-- RLS is the main wall; this is the second one. Start from nothing, then grant only what the
-- app needs. anon gets no access to any table or function.

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

-- Future objects created by the migration role start locked down as well.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from public, anon, authenticated;

-- Read access (rows are still filtered by RLS).
grant select on
  public.profiles, public.stores, public.store_members,
  public.categories, public.brands, public.suppliers, public.products,
  public.product_variants, public.variant_costs, public.variant_stock,
  public.stock_movements, public.employees, public.shifts, public.purchases,
  public.purchase_items, public.sales, public.sale_items, public.sale_payments,
  public.expenses
to authenticated;

-- Column-limited updates: identifiers and store_id can never be changed by a client.
grant update (full_name, phone, locale) on public.profiles to authenticated;
grant update (name, phone, governorate, city, address, tax_registration_no, receipt_footer, receipt_paper_mm)
  on public.stores to authenticated;

grant insert, delete on public.categories, public.brands, public.suppliers,
  public.products, public.product_variants to authenticated;
grant update (name) on public.categories, public.brands to authenticated;
grant update (name, phone, address, notes, active) on public.suppliers to authenticated;
grant update (name, model_code, brand_id, category_id, gender, description, active)
  on public.products to authenticated;
grant update (size, color, sku, barcode, sale_price, reorder_level, active)
  on public.product_variants to authenticated;
grant update (cost_price) on public.variant_costs to authenticated;

grant insert, delete on public.employees, public.expenses to authenticated;
grant update (member_user_id, full_name, phone, job_title, hired_on, active)
  on public.employees to authenticated;
grant update (category, amount, expense_date, note) on public.expenses to authenticated;

-- Only RPC the browser may call in Phase 1.
grant execute on function public.create_store(text, text, text, text, text) to authenticated;
