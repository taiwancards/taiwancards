# frozen_string_literal: true

require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

DEPLOYMENT_ENV = %w[
  SITE_URL
  APP_URL
  APP_HOST
  APP_HOSTS
  ASSETS_BASE_URL
  MEDIA_BASE_URL
  DONATE_SCRIPT_URL
  DONATE_SLUG
  DONATE_ORIGINS
  NGROK_DOMAIN
  CSP_REPORT_ONLY
]
  .freeze

DEPLOYMENT_ENV.each { |name| ENV.delete(name) }

require "rspec/rails"
require "tmpdir"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort(e.to_s.strip)
end

RSpec.configure do |config|
  config.before(:suite) do
    ENV["DATA_ROOT"] = Dir.mktmpdir("taiwancards-test-data")
    ENV["ADMIN_EMAIL"] = "new.learner@example.com"
    ENV["ADMIN_NAME"] = "New Learner"
    ENV["ADMIN_GOOGLE_EMAIL"] = "new.learner@example.com"
  end

  config.before { Huayu::MoeAudio.reset! }

  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include(FactoryBot::Syntax::Methods)
  config.include(ActiveSupport::Testing::TimeHelpers)
  config.include(ActiveJob::TestHelper)

  config.include(LocalisedPaths, type: :request)
  config.include(LocalisedPaths, type: :system)
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework(:rspec)
    with.library(:rails)
  end
end
