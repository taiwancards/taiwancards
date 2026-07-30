# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

require_relative "../lib/font_assets"
require_relative "../lib/shared_assets"
require_relative "../lib/font_url_compiler"

module Taiwancards
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks font_assets.rb shared_assets.rb font_url_compiler.rb corpora])

    config.assets.compilers << ["text/css", FontUrlCompiler]

    config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

    config.generators.system_tests = nil

    config.time_zone = "Asia/Taipei"
    config.active_record.default_timezone = :utc

    config.i18n.available_locales = %i[en ru]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [:en]

    config.generators do |g|
      g.test_framework(
        :rspec,
        view_specs: false,
        helper_specs: false,
        routing_specs: false
      )
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.helper false
      g.assets false
    end

    config.middleware.insert_before(
      ActionDispatch::Static,
      Rack::Static,
      urls: SharedAssets::MOUNTS.map { |mount| "/#{mount}" },
      root: SharedAssets.root.to_s,
      cascade: true,
      header_rules: [
        [
          :all,
          {
            "cache-control" => FontAssets::CACHE_CONTROL,
            "access-control-allow-origin" => "*",
            "timing-allow-origin" => "*"
          }
        ]
      ]
    )
  end
end
