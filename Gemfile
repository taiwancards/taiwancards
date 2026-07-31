# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.6"
gem "rails", "8.1.3.1"

gem "bcrypt"
gem "bootsnap", require: false
gem "dtwrb", ">= 1.0"
gem "importmap-rails"
gem "nokolexbor", require: false
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"
gem "pg"
gem "propshaft"
gem "puma"
gem "rails-i18n"
gem "rexml", require: false
gem "roo", require: false
gem "slim-rails"
gem "solid_cache"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "rspec-rails"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "parallel_tests"
  gem "shoulda-matchers"
  gem "simplecov", require: false
end
