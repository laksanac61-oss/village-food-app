#!/usr/bin/env bash
# Loads the migration into a throwaway local Postgres and runs the flow checks.
# Needs Postgres server binaries (initdb, pg_ctl) on PATH or in /usr/lib/postgresql/*/bin.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGBIN="$(dirname "$(command -v initdb 2>/dev/null || ls /usr/lib/postgresql/*/bin/initdb | tail -1)")"
DIR="$(mktemp -d)"
RUN=()
if [ "$(id -u)" = 0 ]; then chown postgres "$DIR"; RUN=(su postgres -c); fi
run() { if [ ${#RUN[@]} -gt 0 ]; then "${RUN[@]}" "$*"; else bash -c "$*"; fi; }
cp "$ROOT"/supabase/tests/*.sql "$ROOT"/supabase/migrations/*.sql "$DIR"/ && chmod 644 "$DIR"/*.sql
run "$PGBIN/initdb -D $DIR/data -A trust >/dev/null && $PGBIN/pg_ctl -D $DIR/data -o '-p 5499 -k $DIR -c listen_addresses= -c wal_level=logical' -l $DIR/log -w start >/dev/null"
trap 'run "$PGBIN/pg_ctl -D $DIR/data stop -m fast >/dev/null"; rm -rf "$DIR"' EXIT
FILES="-f $DIR/stubs.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do FILES="$FILES -f $DIR/$(basename "$f")"; done
run "psql -h $DIR -p 5499 -d postgres -v ON_ERROR_STOP=1 -q -o /dev/null $FILES -f $DIR/flows.sql"
