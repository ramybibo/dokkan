#!/usr/bin/env bash
# Runs the whole database test suite against a throwaway local Postgres 16:
#   bootstrap (fake Supabase roles/auth) -> every migration in order -> RLS tests.
# Requires Postgres 16 server binaries (initdb, pg_ctl) and psql on the machine.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-/usr/lib/postgresql/16/bin}"
WORK="$(mktemp -d /tmp/dokkan-pg.XXXXXX)"
PORT="${PGPORT_TEST:-54330}"

# Postgres refuses to run as root, so drop to the postgres user when needed.
if [ "$(id -u)" -eq 0 ]; then
  chown postgres:postgres "$WORK"
  AS_PG=(runuser -u postgres --)
else
  AS_PG=()
fi

cleanup() {
  "${AS_PG[@]}" "$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

"${AS_PG[@]}" "$PGBIN/initdb" -D "$WORK/data" --auth=trust -U postgres >/dev/null
"${AS_PG[@]}" "$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -k $WORK -c listen_addresses=''" \
  -l "$WORK/server.log" -w start >/dev/null

PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q -P pager=off)
"${PSQL[@]}" -d postgres -c "create database dokkan_test" >/dev/null
PSQL+=(-d dokkan_test)

"${PSQL[@]}" -f "$ROOT/supabase/tests/00_bootstrap_local.sql"
for migration in "$ROOT"/supabase/migrations/*.sql; do
  echo "applying $(basename "$migration")"
  "${PSQL[@]}" -f "$migration"
done

# -t -A prints plain rows; the suite raises an error (non-zero exit) if any check fails.
"${PSQL[@]}" -t -A -f "$ROOT/supabase/tests/01_rls.sql" | grep -E '^(PASS|FAIL)|^[0-9]+\|[0-9]+$'
echo "database tests passed"
