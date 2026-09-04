set dotenv-load
set default-list

server := trim_start_match(env('RENDER_SERVER', ''), 'srv-')
region := env('RENDER_REGION', 'singapore')
host := "srv-" + server + "@ssh." + region + ".render.com"
project := "/opt/render/project/src"

db_name := env('DB_NAME', 'taiwancards_development')
db_port := env('PGPORT', '5432')
dump := env('DUMP', 'tmp/render.dump')
parallel := env('PARALLEL', num_cpus())

ssh_opts := "-o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new"

# Start the app: Puma, Tailwind watcher, optional ngrok tunnel
[group('dev')]
dev:
    #!/usr/bin/env bash
    set -uo pipefail
    port="${APP_PORT:-3000}"

    if command -v pg_isready > /dev/null 2>&1; then
      pg_isready -h localhost -p {{ db_port }} -q
      ready=$?
    else
      nc -z localhost {{ db_port }} > /dev/null 2>&1
      ready=$?
    fi
    if [ "$ready" -ne 0 ]; then
      echo "just dev: no PostgreSQL answering on port {{ db_port }}. Start it and try again." >&2
      exit 1
    fi

    holders=$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2> /dev/null)
    if [ -n "$holders" ]; then
      for pid in $holders; do
        cwd=$(lsof -a -p "$pid" -d cwd -Fn 2> /dev/null | sed -n 's/^n//p' | head -1)
        echo "just dev: port $port held by pid $pid ($(/bin/ps -o command= -p "$pid" | cut -c1-60)) in ${cwd:-?} — killing it."
      done
      kill $holders 2> /dev/null
      sleep 1
      survivors=$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2> /dev/null)
      if [ -n "$survivors" ]; then
        kill -9 $survivors 2> /dev/null
        sleep 1
      fi
      rm -f tmp/pids/dev.pid tmp/pids/server.pid
    fi

    exec bin/dev

# Rails console
[group('dev')]
c:
    bin/rails console

# Rebuild the test database and run all specs with coverage
[group('dev')]
s:
    RAILS_ENV=test bin/rails db:drop db:create db:schema:load
    rm -rf coverage/.resultset.json coverage/.resultset.json.lock
    COVERAGE=1 bin/rspec

# Run all specs in parallel with coverage
[group('dev')]
ss:
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p tmp
    rm -rf coverage/.resultset.json coverage/.resultset.json.lock
    log_lines=0
    if [ -s tmp/parallel_runtime_rspec.log ]; then
        log_lines=$(wc -l < tmp/parallel_runtime_rspec.log | tr -d ' ')
    fi
    if [ "$log_lines" -gt 0 ]; then
        echo "[parallel_rspec] runtime grouping, $log_lines entries in the log"
        grouping=(--group-by runtime --allowed-missing 99)
    else
        echo "[parallel_rspec] runtime log empty, grouping by filesize; the log is built this run"
        grouping=(--group-by filesize)
    fi
    COVERAGE=1 RAILS_ENV=test bundle exec parallel_rspec -n {{ parallel }} \
        "${grouping[@]}" spec/ 2>&1 | tee tmp/parallel_rspec.out
    status=${PIPESTATUS[0]}
    failed=$(sed 's/\x1b\[[0-9;]*m//g' tmp/parallel_rspec.out | grep -E '^rspec \./spec/' | sort -u)
    if [ -n "$failed" ]; then
        printf '\n── failed examples ──\n%s\n' "$failed"
    fi
    exit "$status"

# Prepare the parallel test databases, then run them
[group('dev')]
ssp: && ss
    PARALLEL_TEST_PROCESSORS={{ parallel }} RAILS_ENV=test bin/rake parallel:prepare

# Unit tests for the corpus scripts, no Rails needed
[group('dev')]
sc:
    cd corpora && rake test

# Migrate the test and development databases
[group('dev')]
m:
    RAILS_ENV=test bin/rails db:migrate
    bin/rails db:migrate

# Rebuild the static marketing site in site/ from the app pages
[group('dev')]
site:
    bin/rails site:build

# Format Ruby, Python and shell, then autocorrect with RuboCop
[group('dev')]
lint:
    rubyfmt -i . && ruff format . > /dev/null && shfmt -f . | xargs shfmt -w -i 2 -s -sr

# Static analysis and dependency audit
[group('dev')]
sec:
    bin/brakeman -q
    bin/bundler-audit check --update

# Rails console on Render, over SSH
[group('render')]
pc: _require-server
    ssh -t {{ ssh_opts }} "{{ host }}" "cd {{ project }} && bundle exec rails console"

# Shell on Render
[group('render')]
psh: _require-server
    ssh -t {{ ssh_opts }} "{{ host }}" "cd {{ project }} && exec bash -l"

# Migrate the Render database
[group('render')]
pm: _require-server
    ssh {{ ssh_opts }} "{{ host }}" "cd {{ project }} && bundle exec rails db:migrate"

# Run a rake task on Render, e.g. just prake huayu:census
[group('render')]
prake task: _require-server
    ssh {{ ssh_opts }} "{{ host }}" "cd {{ project }} && bundle exec rails {{ task }}"

# psql into the Render database
[group('render')]
pdb: _require-db
    psql "$PROD_DATABASE_URL"

# Count what the dictionary holds
[group('content')]
census:
    bin/rails huayu:census

# Show where bulk data lives and its size
[group('content')]
doctor:
    bin/rails data:doctor

# Rebuild the local database from source files
[group('content')]
rebuild-db:
    CONFIRM=yes bin/install-local

# Copy the whole local database to Render as one dump
[group('content')]
rebuild-db-render:
    CONFIRM=yes bin/rebuild-db-render.sh

# Push every bucket: archive, media, assets, runtime
[group('content')]
dist:
    bin/distribute all

# Print every transfer plan without moving a byte
[group('content')]
dist-plan:
    bin/distribute all --dry-run

# Everything the running app reads, to the runtime bucket
[group('content')]
dist-runtime:
    bin/distribute runtime

# Everything the next deploy needs, in R2: runtime data, offline packs, assets
[group('content')]
prep: dist-runtime offline dist-assets

# Ask Render to build and roll out the current commit, without waiting for a push
[group('deploy')]
release:
    bin/rails deploy:release

# Render the guest pages into the offline packs
[group('content')]
offline *packs:
    bin/rails "offline:build[{{packs}}]"

# Show what the built offline packs hold
[group('content')]
offline-list:
    bin/rails offline:list

# Cold archive to the private R2 bucket
[group('content')]
dist-archive:
    bin/distribute archive

# Fonts and browser data to the public R2 bucket
[group('deploy')]
dist-assets:
    bin/distribute assets

# MOE audio clips to the public R2 bucket
[group('content')]
dist-media:
    bin/distribute media

# Restore the cold archive from R2 to this machine
[group('content')]
dist-pull:
    bin/distribute pull

# Show how much each bucket holds
[group('content')]
dist-status:
    bin/distribute status

# Dump the Render database to {{dump}}
[group('db')]
pdump: _require-db
    mkdir -p tmp
    rm -f "{{ dump }}"
    pg_dump "$PROD_DATABASE_URL" --format=custom --compress=6 --no-owner --no-privileges --file="{{ dump }}"
    @ls -lh "{{ dump }}"

# Drop and recreate the local development database
[group('db')]
drecreate:
    dropdb -h localhost -p {{ db_port }} --if-exists --force "{{ db_name }}"
    createdb -h localhost -p {{ db_port }} "{{ db_name }}"

# Restore {{dump}} into the local development database
[group('db')]
drestore:
    pg_restore --clean --if-exists --no-acl --no-owner --jobs=4 \
        -h localhost -p {{ db_port }} -d "{{ db_name }}" "{{ dump }}"
    bin/rails db:migrate

# Replace the local database with the Render one
[group('db')]
plup: pdump drecreate drestore

[private]
_require-server:
    @test -n "{{ server }}" || { echo "RENDER_SERVER is not set — see .env.dev" >&2; exit 1; }

[private]
_require-db:
    @test -n "${PROD_DATABASE_URL:-}" || { echo "PROD_DATABASE_URL is not set — see .env.dev" >&2; exit 1; }
