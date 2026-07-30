unless ENV["COVERAGE"].to_s.empty?
  require "simplecov"

  SimpleCov.start("rails") do
    enable_coverage(:branch)
    command_name("rspec#{ENV["TEST_ENV_NUMBER"]}")
    merging(true)
    merge_timeout(3600)
    skip("/spec/")
    skip("/config/")
    group("Services", "app/services")
    group("Components", "app/components")
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with(:rspec) do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
