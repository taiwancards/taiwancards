#!/usr/bin/env bash
set -o errexit

PG_STATEMENT_TIMEOUT=0 bundle exec rails data:install || echo "data:install skipped"
PG_STATEMENT_TIMEOUT=0 bundle exec rails deploy:sync || echo "deploy:sync skipped"

exec bundle exec puma -C config/puma.rb -b "tcp://0.0.0.0:$PORT"
