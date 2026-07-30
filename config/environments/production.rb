require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false

  config.eager_load = true

  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true

  config.public_file_server.headers = {"cache-control" => "public, max-age=#{1.year.to_i}"}

  COMPRESSIBLE = %r{\Atext/|\Aapplication/(json|javascript|xml|manifest\+json)}
  MIN_COMPRESSED_BYTES = 1024

  config.middleware.use(
    Rack::Deflater,
    if: -> (_env, _status, headers, _body) {
      next false unless headers["content-type"].to_s.match?(COMPRESSIBLE)

      length = headers["content-length"]
      length.nil? || length.to_i >= MIN_COMPRESSED_BYTES
    }
  )

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)

  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  config.cache_store = :solid_cache_store

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false

  config.active_record.attributes_for_inspect = [:id]

  config.assume_ssl = true
  config.force_ssl = true

  config.hosts += ENV.fetch("APP_HOSTS", "").split(",").map(&:strip).reject(&:empty?)
  config.hosts << /.*\.onrender\.com/
  config.hosts << ENV["RENDER_EXTERNAL_HOSTNAME"] if ENV["RENDER_EXTERNAL_HOSTNAME"].present?
  config.host_authorization = {exclude: -> (request) { request.path == "/up" }}
end
