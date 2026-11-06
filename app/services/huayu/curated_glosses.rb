# frozen_string_literal: true

module Huayu
  class CuratedGlosses
    LOCALES = Locales::ALL

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
      index.fetch(text.to_s, {}).keys
    end

    def gloss(text, locale)
      index.dig(text.to_s, locale.to_s)
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

          glosses = LOCALES.to_h { |locale| [locale, row[locale].to_s.strip] }.compact_blank
          all[text] = glosses.merge(all.fetch(text, {})) if glosses.any?
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
