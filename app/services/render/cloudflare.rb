# frozen_string_literal: true

require "net/http"

module Render
  class Cloudflare
    ENDPOINT = "https://api.cloudflare.com/client/v4"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15
    BATCH = 30

    def self.configured? = ENV["CLOUDFLARE_ZONE_ID"].present? && ENV["CLOUDFLARE_API_TOKEN"].present?

    def purge_everything
      post({purge_everything: true})
    end

    def purge(urls)
      list = Array(urls).map(&:to_s).reject(&:empty?).uniq
      return false if list.empty?

      list.each_slice(BATCH).all? { |slice| post({files: slice}) }
    end

    private

    def post(body)
      return false unless self.class.configured?

      uri = URI("#{ENDPOINT}/zones/#{ENV["CLOUDFLARE_ZONE_ID"]}/purge_cache")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{ENV["CLOUDFLARE_API_TOKEN"]}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      response = http.request(request)
      return true if response.is_a?(Net::HTTPSuccess)

      Rails.logger.warn("Cloudflare purge refused: #{response.code}")
      false
    rescue => e
      Rails.logger.warn("Cloudflare purge failed: #{e.class}: #{e.message}")
      false
    end
  end
end
