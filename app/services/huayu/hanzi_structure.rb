# frozen_string_literal: true

module Huayu
  class HanziStructure
    DATA_PATH = AppData.path("huayu/hanzi_structure.json")

    class << self
      def categories = raw["categories"] || []

      def semantics = raw["semantics"] || []

      def series = raw["series"] || []

      def walkthroughs = raw["walkthroughs"] || []

      def strokes_basic = raw["strokes_basic"] || []

      def strokes_compound = raw["strokes_compound"] || []

      def yongzi = raw["yongzi"] || []

      def order_rules = raw["order_rules"] || []

      def any? = categories.any?

      def note(key, locale = I18n.locale)
        row = Array(raw["notes"]).find { |item| item["key"] == key.to_s }
        return nil if row.nil?

        text(row, locale)
      end

      def text(row, locale = I18n.locale)
        return nil if row.nil?

        (locale.to_s == "ru" ? row["ru"] : row["en"]).presence || row["en"]
      end

      def name(row, locale = I18n.locale)
        return nil if row.nil?

        (locale.to_s == "ru" ? row["ru_name"] : row["en_name"]).presence
      end

      def note_for(row, locale = I18n.locale)
        return nil if row.nil?

        (locale.to_s == "ru" ? row["ru_note"] : row["en_note"]).presence
      end

      def reset!
        @raw = nil
      end

      private

      def raw
        @raw ||= begin
          JSON.parse(File.read(DATA_PATH))
        rescue Errno::ENOENT, JSON::ParserError => e
          Rails.logger.error("hanzi structure data unavailable at #{DATA_PATH}: #{e.class}: #{e.message}")
          {}
        end
      end
    end
  end
end
