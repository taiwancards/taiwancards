#!/usr/bin/env bash
set -o errexit

bundle install

mkdir -p app/assets/builds

SECRET_KEY_BASE_DUMMY=1 bundle exec rails deploy:hydrate

SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:clean
