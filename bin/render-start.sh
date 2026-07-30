#!/usr/bin/env bash
set -o errexit

exec bundle exec puma -C config/puma.rb -b "tcp://0.0.0.0:$PORT"
