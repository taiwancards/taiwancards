#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
. bin/_env.sh
. bin/_lib.sh
load_env

REMOTE_ROOT="/var/data"
REGION="${RENDER_REGION:-singapore}"
SERVER="${RENDER_SERVER:-}"
HEADROOM_PERCENT=15

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new
  -o UpdateHostKeys=no -o ServerAliveInterval=15)

target_of() { [ "$1" = "." ] && echo "$REMOTE_ROOT" || echo "$REMOTE_ROOT/$1"; }

remote() { ssh -n "${SSH_OPTS[@]}" "$HOST" "$1"; }

measure() {
  local src=$1
  shift
  local bytes=0 count=0 entry file
  for entry in "$@"; do
    if [ -d "$src/$entry" ]; then
      while IFS= read -r file; do
        bytes=$((bytes + $(size_of "$file")))
        count=$((count + 1))
      done < <(find "$src/$entry" -type f)
    elif [ -f "$src/$entry" ]; then
      bytes=$((bytes + $(size_of "$src/$entry")))
      count=$((count + 1))
    fi
  done
  echo "$bytes $count"
}

[ -n "$SERVER" ] || die "RENDER_SERVER is not set; put it in .env"
HOST="srv-${SERVER#srv-}@ssh.${REGION}.render.com"

if [ "${CONFIRM:-}" != "yes" ] && [ -z "${DRY_RUN:-}" ]; then
  cat << USAGE
Bring $REMOTE_ROOT on Render in line with this checkout.

  1. measure what is present locally
  2. check connectivity and free space on $REMOTE_ROOT
  3. sync every section over rsync: send what changed, drop what is gone
  4. verify file count and volume on the far side

Runs as often as you like: unchanged files are compared and skipped, so a
second run transfers nothing. The server downloads nothing of its own —
fonts, audio and dictionaries are built here and sent whole.

  CONFIRM=yes bin/rebuild-data-render.sh
  DRY_RUN=1 bin/rebuild-data-render.sh             plan only, no changes
  WIPE=1 CONFIRM=yes bin/rebuild-data-render.sh    empty the disk first

Service: $HOST
USAGE
  exit 1
fi

STARTED=$(date +%s)
printf "%s%s%s\n" "$B" "DATA TRANSFER TO RENDER" "$R"
printf "%s%s · started %s%s\n" "$DIM" "$HOST" "$(date '+%H:%M:%S')" "$R"

rule
printf "%sPAYLOAD%s\n" "$B" "$R"
rule

SECTIONS=$(bin/rails runner 'puts Deploy::Catalog.plan') ||
  die "could not read the section list from Deploy::Catalog"
[ -n "$SECTIONS" ] || die "Deploy::Catalog listed no sections"

TOTAL_BYTES=0
TOTAL_FILES=0
SECTION_COUNT=0
PLAN=""

while IFS=$'\t' read -r title src dest mode entries; do
  [ -z "$title" ] && continue
  [ -d "$src" ] || die "no such directory: $src"

  read -r bytes count <<< "$(measure "$src" $entries)"
  [ "$count" -gt 0 ] || die "$src is empty; has everything been built locally?"

  TOTAL_BYTES=$((TOTAL_BYTES + bytes))
  TOTAL_FILES=$((TOTAL_FILES + count))
  SECTION_COUNT=$((SECTION_COUNT + 1))
  PLAN="${PLAN}${title}	${src}	${dest}	${mode}	${bytes}	${count}	${entries}
"

  printf "  "
  pad "$title" 24
  printf " %6s files %11s  %s→ %s%s\n" \
    "$count" "$(human "$bytes")" "$DIM" "$(target_of "$dest")" "$R"
done <<< "$SECTIONS"

printf "  %s\n" "$(printf '%*s' 62 '' | tr ' ' '-')"
printf "  "
pad "TOTAL" 24
printf " %6s files %11s\n" "$TOTAL_FILES" "$(human "$TOTAL_BYTES")"

rule
printf "%sSERVICE%s\n" "$B" "$R"
rule

printf "  %s→%s connecting to %s … " "$CYAN" "$R" "$HOST"
remote "true" > /dev/null 2>&1 || die "ssh to $HOST failed"
printf "%s✓%s\n" "$GREEN" "$R"

DF=$(remote "df -Pk $REMOTE_ROOT | tail -1")
DISK_TOTAL=$(($(echo "$DF" | awk '{print $2}') * 1024))
DISK_USED=$(($(echo "$DF" | awk '{print $3}') * 1024))
DISK_FREE=$(($(echo "$DF" | awk '{print $4}') * 1024))
NEEDED=$((TOTAL_BYTES + TOTAL_BYTES * HEADROOM_PERCENT / 100))

printf "  disk %s · used %s · free now %s\n" \
  "$(human "$DISK_TOTAL")" "$(human "$DISK_USED")" "$(human "$DISK_FREE")"
printf "  required with %d%% headroom: %s\n" "$HEADROOM_PERCENT" "$(human "$NEEDED")"

[ "$NEEDED" -le "$DISK_TOTAL" ] || die "disk holds only $(human "$DISK_TOTAL"); payload does not fit"
ok "enough space"

if [ -n "${DRY_RUN:-}" ]; then
  rule
  printf "%sPlan only. Nothing was sent or deleted.%s\n" "$YELLOW" "$R"
  exit 0
fi

if [ -n "${WIPE:-}" ]; then
  rule
  printf "%sWIPE%s\n" "$B" "$R"
  rule

  printf "  %s→%s removing everything under %s … " "$CYAN" "$R" "$REMOTE_ROOT"
  remote "rm -rf ${REMOTE_ROOT:?}/* ${REMOTE_ROOT:?}/.[!.]* > /dev/null 2>&1; true"
  LEFT=$(remote "ls -A $REMOTE_ROOT | wc -l" | tr -d ' ')
  [ "$LEFT" = "0" ] || die "$LEFT entries left after the wipe"
  printf "%s✓%s empty\n" "$GREEN" "$R"
fi

rule
printf "%sSYNC%s\n" "$B" "$R"
rule

command -v rsync > /dev/null 2>&1 || die "rsync is not in PATH"
remote "command -v rsync > /dev/null" || die "the service has no rsync"

RSYNC_OPTS=(-rltz --no-perms --no-owner --no-group --omit-dir-times --partial --stats
  --exclude '._*' --exclude '.DS_Store' -e "ssh ${SSH_OPTS[*]}")

SENT_FILES=0
INDEX=0

while IFS=$'\t' read -r title src dest mode bytes count entries <&3; do
  [ -z "$title" ] && continue
  INDEX=$((INDEX + 1))

  printf "\n%s[%d/%d]%s " "$B" "$INDEX" "$SECTION_COUNT" "$R"
  pad "$title" 24
  printf " %s%s files, %s%s\n" "$DIM" "$count" "$(human "$bytes")" "$R"

  TARGET=$(target_of "$dest")
  remote "mkdir -p '$TARGET'"

  SOURCES=()
  if [ "$entries" = "." ]; then
    SOURCES=("$src/")
  else
    for entry in $entries; do SOURCES+=("$src/$entry"); done
  fi

  PRUNE=()
  [ "$dest" = "." ] || PRUNE=(--delete)

  began=$(date +%s)
  STATS=$(rsync "${RSYNC_OPTS[@]}" ${PRUNE[@]+"${PRUNE[@]}"} "${SOURCES[@]}" "$HOST:$TARGET/") ||
    die "rsync failed for $title"
  took=$(($(date +%s) - began))

  moved=$(printf '%s\n' "$STATS" | awk -F': ' '/^Number of files transferred/ {print $2; exit}')
  volume=$(printf '%s\n' "$STATS" | awk -F': ' '/^Total transferred file size/ {print $2; exit}')
  moved=${moved:-0}
  SENT_FILES=$((SENT_FILES + moved))

  if [ "$moved" = "0" ]; then
    ok "already in place, nothing sent"
  else
    ok "sent $moved of $count files (${volume:-?}), in ${took}s"
  fi

  if [ "$dest" != "." ]; then
    REMOTE_COUNT=$(remote "find '$TARGET' -type f | wc -l" | tr -d ' ')
    [ "$REMOTE_COUNT" -eq "$count" ] || die "$REMOTE_COUNT files on the server, $count expected"
  fi
done 3<<< "$PLAN"

rule
printf "%sVERIFICATION%s\n" "$B" "$R"
rule

REMOTE_FILES=$(remote "find $REMOTE_ROOT -type f | wc -l" | tr -d ' ')
REMOTE_TOTAL=$(($(remote "du -sk $REMOTE_ROOT | awk '{print \$1}'") * 1024))

printf "  local   %6s files %11s\n" "$TOTAL_FILES" "$(human "$TOTAL_BYTES")"
printf "  Render  %6s files %11s\n" "$REMOTE_FILES" "$(human "$REMOTE_TOTAL")"
printf "\n  %sdisk root:%s\n" "$DIM" "$R"
remote "ls -1 $REMOTE_ROOT" | sed 's/^/    /'

[ "$REMOTE_FILES" -ge "$TOTAL_FILES" ] || die "fewer files on the server than were sent"
[ "$REMOTE_FILES" -eq "$TOTAL_FILES" ] ||
  warn "$((REMOTE_FILES - TOTAL_FILES)) files on the server were not sent by this run"

APPLEDOUBLE=$(remote "find $REMOTE_ROOT -type f -name '._*' | wc -l" | tr -d ' ')
[ "$APPLEDOUBLE" = "0" ] || die "$APPLEDOUBLE macOS metadata files reached the disk"

ELAPSED=$(($(date +%s) - STARTED))
rule
if [ "$SENT_FILES" -eq 0 ]; then
  printf "%s%s IN SYNC%s in %d:%02d · nothing needed sending\n" \
    "$B" "$GREEN" "$R" $((ELAPSED / 60)) $((ELAPSED % 60))
else
  printf "%s%s DONE%s in %d:%02d · %d files sent\n" \
    "$B" "$GREEN" "$R" $((ELAPSED / 60)) $((ELAPSED % 60)) "$SENT_FILES"
fi
printf "%snext: bin/rebuild-db-render.sh for the database%s\n" "$DIM" "$R"
