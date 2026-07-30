#!/usr/bin/env bash
set -o errexit

export PG_STATEMENT_TIMEOUT=0
export PG_LOCK_TIMEOUT=0

bundle exec rails db:prepare
bundle exec rails db:seed
