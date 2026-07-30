# frozen_string_literal: true

module Huayu
  class TeaClasses
    DATA_PATH = AppData.path("huayu/tea_classes.json")

    Row = Data.define(:text, :pinyin, :oxidation, :roast, :ru_name, :en_name, :ru, :en) do
      def name(locale = I18n.locale)
        (locale.to_s == "ru" ? ru_name : en_name).presence
      end

      def body(locale = I18n.locale)
        (locale.to_s == "ru" ? ru : en).presence || en
      end
    end

    class << self
      def classes
        @classes ||= build(raw["classes"])
      end

      def scale
        @scale ||= build(raw["scale"])
      end

      def notes
        @notes ||= Array(raw["notes"]).to_h do |row|
          [row["key"], {"ru" => row["ru"], "en" => row["en"]}]
        end
      end

      def note(key, locale = I18n.locale)
        row = notes[key.to_s] or return nil

        (locale.to_s == "ru" ? row["ru"] : row["en"]).presence || row["en"]
      end

      def any?
        classes.any?
      end

      def reset!
        @classes = nil
        @scale = nil
        @notes = nil
        @raw = nil
      end

      private

      def build(rows)
        Array(rows).map do |row|
          Row.new(
            text: row["text"],
            pinyin: row["pinyin"],
            oxidation: row["oxidation"],
            roast: row["roast"],
            ru_name: row["ru_name"],
            en_name: row["en_name"],
            ru: row["ru"],
            en: row["en"]
          )
        end
      end

      def raw
        @raw ||= begin
          JSON.parse(File.read(DATA_PATH))
        rescue Errno::ENOENT, JSON::ParserError => e
          Rails.logger.error("tea classes data unavailable at #{DATA_PATH}: #{e.class}: #{e.message}")
          {"classes" => [], "scale" => [], "notes" => []}
        end
      end
    end
  end
end
