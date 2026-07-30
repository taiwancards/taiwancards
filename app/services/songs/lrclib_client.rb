# frozen_string_literal: true

require "net/http"

module Songs
  class LrclibClient
    HOST = ENV["LRCLIB_HOST"].to_s
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15
    LIMIT = 20

    def search(query)
      return [] if query.to_s.strip.blank?

      rows = get_json("/api/search?q=#{CGI.escape(query.to_s.strip)}")
      return [] unless rows.is_a?(Array)

      rows.first(LIMIT).map { |row| normalize(row) }
    end

    def fetch(id)
      row = get_json("/api/get/#{id.to_i}")
      row.is_a?(Hash) ? normalize(row) : nil
    end

    private

    def normalize(row)
      {
        "id" => row["id"],
        "track" => row["trackName"].to_s,
        "artist" => row["artistName"].to_s,
        "album" => row["albumName"].to_s,
        "duration" => row["duration"],
        "plain" => row["plainLyrics"].to_s,
        "synced" => row["syncedLyrics"].to_s
      }
    end

    def get_json(path)
      return nil if HOST.empty?

      uri = URI("#{HOST}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = Sources.user_agent
      request["Accept"] = "application/json"

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue => e
      Rails.logger.warn("LRCLIB request failed: #{e.class}: #{e.message}")
      nil
    end
  end
end
