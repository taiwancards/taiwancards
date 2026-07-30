#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
. bin/_env.sh
. bin/_lib.sh
load_env

DUMP="${DUMP:-tmp/render.dump}"
PROD="${PROD_DATABASE_URL:-}"

prod_sql() { psql "$PROD" -tAX -c "$1"; }

for tool in pg_dump pg_restore psql; do
  command -v "$tool" > /dev/null 2>&1 || die "$tool is not in PATH"
done

[ -n "$PROD" ] || die "PROD_DATABASE_URL is not set; put it in .env"

LOCAL_DB=$(bin/rails runner 'print ActiveRecord::Base.connection_db_config.configuration_hash[:database]')
LOCAL_HOST=$(bin/rails runner 'print ActiveRecord::Base.connection_db_config.configuration_hash[:host] || "localhost"')
LOCAL_PORT=$(bin/rails runner 'print ActiveRecord::Base.connection_db_config.configuration_hash[:port] || 5432')
LOCAL_SIZE=$(bin/rails runner 'print ActiveRecord::Base.connection.select_value("SELECT pg_database_size(current_database())")')
LOCAL_VERSION=$(bin/rails runner 'print ActiveRecord::Base.connection.select_value("SHOW server_version_num")')
LOCAL_MAJOR=$((LOCAL_VERSION / 10000))

if [ "${CONFIRM:-}" != "yes" ] && [ -z "${DRY_RUN:-}" ]; then
  cat << USAGE
Load the whole database onto Render as a single dump, directly over psql.

  1. version check: local and Render must be compatible
  2. pg_dump of the entire local database in custom format
  3. FULL drop of the public schema on Render
  4. parallel pg_restore over the direct URL
  5. ANALYZE and per-table row verification

Everything is transferred: dictionary, sentences, links, settings and accounts.
All progress on Render is overwritten.

  CONFIRM=yes bin/rebuild-db-render.sh
  DRY_RUN=1 bin/rebuild-db-render.sh    inspect only, no changes

Local database: $LOCAL_DB ($(human "$LOCAL_SIZE"))
USAGE
  exit 1
fi

STARTED=$(date +%s)
printf "%s%s%s\n" "$B" "DATABASE TRANSFER TO RENDER" "$R"
printf "%sstarted %s%s\n" "$DIM" "$(date '+%H:%M:%S')" "$R"

rule
printf "%sCHECKS%s\n" "$B" "$R"
rule

printf "  %s→%s connecting to Render … " "$CYAN" "$R"
PROD_VERSION=$(prod_sql "SHOW server_version_num" 2> /dev/null | tr -d '[:space:]') ||
  die "cannot connect using PROD_DATABASE_URL"
[ -n "$PROD_VERSION" ] || die "cannot connect using PROD_DATABASE_URL"
PROD_MAJOR=$((PROD_VERSION / 10000))
printf "%s✓%s\n" "$GREEN" "$R"

printf "  local   PostgreSQL %s, database %s, %s\n" "$LOCAL_MAJOR" "$LOCAL_DB" "$(human "$LOCAL_SIZE")"
PROD_SIZE=$(prod_sql "SELECT pg_database_size(current_database())" | tr -d '[:space:]')
printf "  Render  PostgreSQL %s, currently using %s\n" "$PROD_MAJOR" "$(human "$PROD_SIZE")"

if [ "$PROD_MAJOR" -lt "$LOCAL_MAJOR" ]; then
  die "Render runs PostgreSQL $PROD_MAJOR, the dump comes from $LOCAL_MAJOR; an older server cannot load it"
fi
ok "versions are compatible"

printf "\n  %scurrently on Render:%s\n" "$DIM" "$R"
prod_sql "SELECT relname || ' ' || n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 6" |
  awk 'NF { printf("    %-26s %10s\n", $1, $2) }' || true

if [ -n "${DRY_RUN:-}" ]; then
  rule
  printf "%sPlan only. Nothing was dumped or deleted.%s\n" "$YELLOW" "$R"
  exit 0
fi

rule
printf "%sDUMP%s\n" "$B" "$R"
rule

mkdir -p "$(dirname "$DUMP")"
rm -f "$DUMP"

printf "  dumping %s → %s\n" "$LOCAL_DB" "$DUMP"
began=$(date +%s)
if command -v pv > /dev/null 2>&1; then
  pg_dump --format=custom --compress=6 --no-owner --no-privileges \
    --host="$LOCAL_HOST" --port="$LOCAL_PORT" "$LOCAL_DB" |
    pv -N "dump" > "$DUMP"
else
  pg_dump --format=custom --compress=6 --no-owner --no-privileges \
    --host="$LOCAL_HOST" --port="$LOCAL_PORT" --file="$DUMP" "$LOCAL_DB"
fi
[ -s "$DUMP" ] || die "the dump is empty"

DUMP_SIZE=$(stat -f%z "$DUMP" 2> /dev/null || stat -c%s "$DUMP")
ENTRIES=$(pg_restore --list "$DUMP" | awk '/^[0-9]/' | wc -l | tr -d ' ')
ok "$(human "$DUMP_SIZE"), $ENTRIES table-of-contents entries, in $(($(date +%s) - began))s"

rule
printf "%sWIPE ON RENDER%s\n" "$B" "$R"
rule

printf "  %s→%s dropping the public schema … " "$CYAN" "$R"
psql "$PROD" -qX -v ON_ERROR_STOP=1 << 'SQL' > /dev/null || die "failed to drop the schema"
drop schema if exists public cascade;
create schema public;
grant all on schema public to public;
SQL
printf "%s✓%s\n" "$GREEN" "$R"

rule
printf "%sRESTORE%s\n" "$B" "$R"
rule

CORES=$(sysctl -n hw.ncpu 2> /dev/null || nproc 2> /dev/null || echo 4)
JOBS=$((CORES > 8 ? 8 : CORES))
printf "  pg_restore with %s jobs, target about %s\n\n" "$JOBS" "$(human "$LOCAL_SIZE")"

began=$(date +%s)
pg_restore --no-owner --no-privileges --jobs="$JOBS" --dbname="$PROD" "$DUMP" \
  > tmp/render-restore.log 2>&1 &
RESTORE_PID=$!

while kill -0 "$RESTORE_PID" 2> /dev/null; do
  CURRENT=$(prod_sql "SELECT pg_database_size(current_database())" 2> /dev/null | tr -d '[:space:]' || echo 0)
  [ -n "$CURRENT" ] || CURRENT=0
  PERCENT=$((CURRENT * 100 / LOCAL_SIZE))
  printf "\r  %s  %s · elapsed %ds   " \
    "$(bar "$PERCENT")" "$(human "$CURRENT")" $(($(date +%s) - began))
  sleep 3
done

wait "$RESTORE_PID" && RESTORE_OK=1 || RESTORE_OK=0
printf "\r  %s  %s · elapsed %ds   \n" "$(bar 100)" "$(human "$(prod_sql "SELECT pg_database_size(current_database())" | tr -d '[:space:]')")" $(($(date +%s) - began))

if [ "$RESTORE_OK" -eq 0 ]; then
  printf "\n"
  tail -30 tmp/render-restore.log
  die "pg_restore failed; full log in tmp/render-restore.log"
fi

WARNINGS=$(grep -c "^pg_restore: warning" tmp/render-restore.log 2> /dev/null || true)
[ "${WARNINGS:-0}" -gt 0 ] && warn "$WARNINGS warnings in the log (tmp/render-restore.log)"
ok "restored in $(($(date +%s) - began))s"

rule
printf "%sFINALISE%s\n" "$B" "$R"
rule

printf "  %s→%s stamping the schema as production … " "$CYAN" "$R"
psql "$PROD" -qX -v ON_ERROR_STOP=1 \
  -c "update ar_internal_metadata set value = 'production', updated_at = now() where key = 'environment'" \
  > /dev/null || die "could not stamp ar_internal_metadata"
STAMP=$(prod_sql "select value from ar_internal_metadata where key = 'environment'" | tr -d '[:space:]')
[ "$STAMP" = "production" ] || die "ar_internal_metadata still says '$STAMP'"
printf "%s✓%s\n" "$GREEN" "$R"

printf "  %s→%s ANALYZE on Render … " "$CYAN" "$R"
psql "$PROD" -qX -c "analyze" > /dev/null || die "ANALYZE failed"
printf "%s✓%s\n" "$GREEN" "$R"

printf "\n  %sper-table row counts%s\n" "$B" "$R"
TABLES="lexemes lexeme_links lexeme_senses sense_examples sentence_words sentence_profiles
lexeme_content_sources content_sources mainland_markers textbook_lessons collections
collection_items settings users"

MISMATCH=0
for table in $TABLES; do
  LOCAL_ROWS=$(bin/rails runner "print ActiveRecord::Base.connection.select_value('SELECT count(*) FROM $table')")
  PROD_ROWS=$(prod_sql "SELECT count(*) FROM $table" | tr -d '[:space:]')
  if [ "$LOCAL_ROWS" = "$PROD_ROWS" ]; then
    printf "    %-26s %10s  %s✓%s\n" "$table" "$PROD_ROWS" "$GREEN" "$R"
  else
    printf "    %-26s %10s  %s✗ local %s%s\n" "$table" "$PROD_ROWS" "$RED" "$LOCAL_ROWS" "$R"
    MISMATCH=$((MISMATCH + 1))
  fi
done

FINAL_SIZE=$(prod_sql "SELECT pg_size_pretty(pg_database_size(current_database()))" | tr -d '\n')
printf "\n  database on Render: %s\n" "$FINAL_SIZE"

ELAPSED=$(($(date +%s) - STARTED))
rule
if [ "$MISMATCH" -eq 0 ]; then
  printf "%s%s DONE%s in %d:%02d\n" "$B" "$GREEN" "$R" $((ELAPSED / 60)) $((ELAPSED % 60))
  printf "%srestart the Render service to pick up the new database%s\n" "$DIM" "$R"
else
  printf "%s%s MISMATCHES: %s%s in %d:%02d\n" "$B" "$RED" "$MISMATCH" "$R" $((ELAPSED / 60)) $((ELAPSED % 60))
  exit 1
fi
