# frozen_string_literal: true

require "net/http"
require "rexml/document"

module News
  class PtsFetcher
    ATTRIBUTION_KEY = "reader.attribution_pts"
    LIMIT = 20

    def initialize(url: ENV["PTS_FEED_URL"].to_s)
      @url = url
    end

    def call(body: nil)
      xml = body || fetch
      return {created: 0, error: "unreachable"} if xml.blank?

      created = 0
      items(xml).first(LIMIT).each do |item|
        next if item[:title].blank? || item[:link].blank?
        next if ReadingText.exists?(source_url: item[:link])

        text, changed = Huayu::SimpToTrad.convert([item[:title], item[:summary]].compact_blank.join("\n\n"))
        ReadingText.create!(
          kind: :news,
          title: item[:title],
          author: "公視 PTS",
          source: "pts",
          source_url: item[:link],
          body: text,
          body_data: {"changed_chars" => changed, "attribution" => I18n.t(ATTRIBUTION_KEY)}
        )
        created += 1
      end

      {created:}
    end

    private

    def items(xml)
      require "rexml"

      REXML::Document.new(xml).elements.to_a("rss/channel/item").map do |node|
        {
          title: node.elements["title"]&.text.to_s.strip,
          link: node.elements["link"]&.text.to_s.strip,
          summary: strip_html(node.elements["description"]&.text.to_s)
        }
      end

    rescue => e
      Rails.logger.warn("PTS feed parse failed: #{e.class}: #{e.message}")
      []
    end

    def strip_html(raw)
      return "" if raw.blank?

      ActionController::Base.helpers.strip_tags(raw).to_s.squeeze(" ").strip
    end

    def fetch
      return nil if @url.blank?

      uri = URI(@url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 15

      response = http.request(Net::HTTP::Get.new(uri))
      response.is_a?(Net::HTTPSuccess) ? response.body : nil
    rescue => e
      Rails.logger.warn("PTS feed fetch failed: #{e.class}: #{e.message}")
      nil
    end
  end
end
