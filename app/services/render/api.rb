# frozen_string_literal: true

require "net/http"

module Render
  class Api
    Misconfigured = Class.new(StandardError)
    Failed = Class.new(StandardError)

    HOST = "https://api.render.com"
    VERSION = "v1"
    TIMEOUT = 30

    def initialize(key: ENV.fetch("RENDER_API_KEY", nil), service: ENV.fetch("RENDER_SERVER", nil))
      @key = key.presence
      @service = service.presence
    end

    def deploy!(clear_cache: false)
      require_settings!
      post("services/#{@service}/deploys", clearCache: clear_cache ? "clear" : "do_not_clear")
    end

    private

    def require_settings!
      missing = {"RENDER_API_KEY" => @key, "RENDER_SERVER" => @service}.select { |_, value| value.blank? }.keys
      raise Misconfigured, "#{missing.join(" and ")} missing from .env — see .env.dev" if missing.any?
    end

    def post(path, payload)
      uri = URI.join(HOST, "/#{VERSION}/#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@key}"
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

      parse(send_request(uri, request))
    end

    def send_request(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(request)
      end
    end

    def parse(response)
      unless response.is_a?(Net::HTTPSuccess)
        raise Failed, "Render answered #{response.code}: #{response.body.to_s.truncate(200)}"
      end

      JSON.parse(response.body)
    end
  end
end
