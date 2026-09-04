# frozen_string_literal: true

module Huayu
  class CuratedGlosses
    LOCALES = %w[en ru].freeze

    PATHS = %w[
      huayu/taiwan_everyday.json
      huayu/medicine.json
      huayu/games.json
      huayu/taiwan_places.json
    ].freeze

    OVERRIDE_PATH = "huayu/gloss_overrides.json"

    def initialize(paths: PATHS)
      @paths = paths
    end

    def owned(text)
      index.fetch(text.to_s, [])
    end

    def owns?(text, locale)
      owned(text).include?(locale.to_s)
    end

    def size
      index.size
    end

    private

    def index
      @index ||= @paths.each_with_object({}) do |relative, all|
        path = Pathname(relative).absolute? ? Pathname(relative) : AppData.path(relative)
        next unless path.exist?

        rows_in(path).each do |row|
          text = row["text"].to_s
          next if text.empty?

          locales = LOCALES.select { |locale| row[locale].to_s.strip.present? }
          all[text] = all.fetch(text, []) | locales if locales.any?
        end
      end
    end

    def rows_in(path)
      parsed = JSON.parse(path.read)
      return parsed.filter_map { |row| row if row.is_a?(Hash) } if parsed.is_a?(Array)

      parsed.filter_map { |text, data| data.merge("text" => text) if data.is_a?(Hash) }
    end
  end
end
