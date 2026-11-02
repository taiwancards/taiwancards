# frozen_string_literal: true

module Huayu
  class TeaClasses
    DATA = JsonData.new("huayu/tea_classes.json", default: {"classes" => [], "scale" => [], "notes" => []})

    Row = Data.define(:text, :pinyin, :oxidation, :roast, :names, :bodies) do
      def name(locale = I18n.locale) = names[locale.to_s].presence

      def body(locale = I18n.locale) = Locales.pick(bodies, locale)
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
          [row["key"], row.slice(*Locales::ALL)]
        end
      end

      def note(key, locale = I18n.locale)
        row = notes[key.to_s] or return nil

        Locales.pick(row, locale)
      end

      def any?
        classes.any?
      end

      def reset!
        @classes = nil
        @scale = nil
        @notes = nil
        DATA.reset!
      end

      private

      def build(rows)
        Array(rows).map do |row|
          Row.new(
            text: row["text"],
            pinyin: row["pinyin"],
            oxidation: row["oxidation"],
            roast: row["roast"],
            names: Locales::ALL.to_h { |code| [code, row["#{code}_name"]] },
            bodies: row.slice(*Locales::ALL)
          )
        end
      end

      def raw = DATA.value
    end
  end
end
