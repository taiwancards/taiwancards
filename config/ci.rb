# frozen_string_literal: true

require "etc"

ROOT = File.expand_path("..", __dir__)
PROCESSORS = ENV.fetch("PARALLEL", Etc.nprocessors).to_i.clamp(1, 32)
RUNTIME_LOG = File.join(ROOT, "tmp/parallel_runtime_rspec.log")
GROUPING = File.size?(RUNTIME_LOG) ? "--group-by runtime --allowed-missing 99" : "--group-by filesize"
AS_PRODUCTION = "SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production"
ASSET_HOST = "ASSETS_BASE_URL=\"$(sed -n 's/^ASSETS_BASE_URL=//p' .env | tr -d '\"' | head -1)\""

CI.run do
  step("Setup", "bin/setup --skip-server")

  step(
    "Format: Ruby, Python, shell",
    "rubyfmt -i . && ruff format . > /dev/null && shfmt -f . | xargs shfmt -w -i 2 -s -sr"
  )
  # step("Style: Ruby", "bin/rubocop") # disabled because it is too slow and not very useful here

  step("Dependencies: lockfile satisfies the Gemfile", "bundle check")
  step("Security: gem advisories", "bin/bundler-audit")
  step("Security: pinned JavaScript", "bin/importmap audit")
  step("Security: code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error")

  step(
    "Database: schema loads and nothing is pending",
    "RAILS_ENV=test bin/rails db:drop db:create db:schema:load db:abort_if_pending_migrations"
  )
  step("Database: every foreign key is indexed", "bin/rails db:health")
  step("Locales: en and ru agree", "bin/rails i18n:check")

  step("Boot: eager load the way production does", "#{AS_PRODUCTION} bin/rails zeitwerk:check")
  step(
    "Assets: compile the way production does",
    "#{ASSET_HOST} #{AS_PRODUCTION} bin/rails assets:precompile && #{AS_PRODUCTION} bin/rails assets:clobber"
  )

  step(
    "Tests: prepare #{PROCESSORS} databases",
    "PARALLEL_TEST_PROCESSORS=#{PROCESSORS} RAILS_ENV=test bin/rake parallel:prepare"
  )
  step(
    "Tests: application on #{PROCESSORS} processes",
    "rm -rf coverage/.resultset.json coverage/.resultset.json.lock && " \
      "COVERAGE=1 RAILS_ENV=test bundle exec parallel_rspec -n #{PROCESSORS} #{GROUPING} spec/"
  )
  step("Tests: corpus scripts", "cd corpora && rake test") if File.directory?(File.join(ROOT, "corpora"))

  step("Static site: rebuild when stale", "bin/rails site:refresh")

  if success?
    heading("Ready to deploy", "Push to main and Render takes it from here")
  else
    failure("Not ready to deploy", "Fix what failed above, then run bin/ci again")
  end
end
