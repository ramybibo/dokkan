# DOKKAN (دُكّان)

Multi-tenant SaaS for shoe store management in Egypt. Arabic (RTL) and English (LTR).
The currency is **Egyptian pound (EGP), permanently** - there is no currency setting or column.

Stack: Next.js (App Router) + TypeScript + Tailwind CSS, Supabase (PostgreSQL + Auth), GitHub, Vercel.

## Status: Phase 1 (foundation)

Included:

- Database schema for the whole product (catalog with size/color variants, stock, purchases, sales,
  shifts, expenses, employees), with strict per-store isolation.
- Row Level Security on every table, least-privilege grants, composite `(store_id, id)` foreign keys
  so a row can never point at another store's data.
- Email + password auth (Supabase), session refresh and route protection in middleware.
- Store onboarding through one transactional database function (`create_store`).
- Arabic RTL / English LTR switching, EGP formatting helpers.

Not built yet (Phase 2+): product screens, POS checkout, inventory and purchase operations,
expenses, shifts, employees, reports, 80 mm receipts. The dashboard says so instead of faking data.

## How isolation works

- Every tenant table has `store_id`. Policies allow a row only if the caller is an *active member*
  of that store, and writes also check the member's role (`owner` / `manager` / `cashier`).
- Financial tables (`sales`, `sale_items`, `sale_payments`, `purchases`, `stock_movements`,
  `variant_stock`, `store_members`) are **read-only for browsers**. Phase 2 writes to them only
  through server-side `SECURITY DEFINER` functions that run as one transaction.
- Cost prices live in `variant_costs`, readable only by owners/managers (never cashiers).
- `stock_movements` is append-only (a trigger rejects UPDATE/DELETE) and stock can never go negative.
- `anon` has no privileges on any table or function.

## Environment variables

Copy `.env.example` and fill in (Supabase: Project Settings -> API):

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Publishable key (safe for the browser) |
| `NEXT_PUBLIC_SITE_URL` | Optional canonical URL for confirmation emails |

Phase 1 does not use a service-role/secret key. Never put one in a `NEXT_PUBLIC_*` variable.

In Supabase, set **Authentication -> URL Configuration**: Site URL to the deployed URL, and add
`<site url>/auth/callback` to the Redirect URLs, or confirmation emails will not return to the app.

## Commands

```bash
npm install
npm run dev          # local app
npm run typecheck
npm run lint
npm run test:unit    # currency, i18n and Egypt data
npm run test:db      # applies every migration to a throwaway local Postgres 16 and runs 76 RLS checks
```

`test:db` needs Postgres 16 server binaries and `psql` locally. It never touches a real project.

## Database migrations

SQL lives in `supabase/migrations/` and is applied in filename order. Apply the same files to the
hosted project (Supabase CLI `db push`, or the dashboard/MCP migration tool). Always re-run
`npm run test:db` after changing a migration.
