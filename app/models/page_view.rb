# frozen_string_literal: true

class PageView < ApplicationRecord
  PATH_LIMIT = 200
  SITE = "site:"
  SEARCH_ENGINES = %w[google bing duckduckgo yandex yahoo baidu naver ecosia qwant].freeze
  MOBILE = /Mobi|iPhone|Android.+Mobile/i
  TABLET = /iPad|Tablet|Android(?!.*Mobile)/i

  def self.count!(path:, referrer:, host:, user_agent:, country:, locale:, day: Date.current)
    upsert_all(
      [
        {
          day:,
          path: path.first(PATH_LIMIT),
          locale: locale.to_s.first(2),
          source: source_of(referrer, host),
          device: device_of(user_agent),
          country: country.to_s.upcase.first(2),
          views: 1
        }
      ],
      unique_by: :index_page_views_on_dimensions,
      on_duplicate: Arel.sql("views = page_views.views + 1"),
      record_timestamps: false
    )
  end

  def self.source_of(referrer, host)
    referring = URI(referrer.to_s).host.to_s.downcase.delete_prefix("www.")
    return "direct" if referring.empty?
    return "internal" if ours?(referring, host.to_s.downcase.delete_prefix("www."))

    engine = SEARCH_ENGINES.find { |name| referring.split(".").include?(name) }
    engine ? "search:#{engine}" : referring.first(100)
  rescue URI::InvalidURIError
    "direct"
  end

  def self.ours?(referring, host)
    short, long = [referring, host].sort_by(&:length)
    long == short || long.end_with?(".#{short}")
  end

  def self.device_of(user_agent)
    return "tablet" if user_agent.to_s.match?(TABLET)
    return "mobile" if user_agent.to_s.match?(MOBILE)

    "desktop"
  end
end
