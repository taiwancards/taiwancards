# frozen_string_literal: true

module Huayu
  class Holidays
    DATA = JsonData.new("huayu/holidays.json", default: {"holidays" => [], "sources" => []})

    Word = Data.define(:traditional, :pinyin, :zhuyin, :gloss_en, :gloss_ru) do
      def gloss(locale = I18n.locale)
        (locale.to_s == "ru" ? gloss_ru : gloss_en).presence || gloss_en
      end
    end

    Entry = Data.define(
      :key,
      :traditional,
      :pinyin,
      :aka,
      :rule,
      :rule_en,
      :rule_ru,
      :public_holiday,
      :summary_en,
      :summary_ru,
      :food_en,
      :food_ru,
      :words
    ) do
      def summary(locale = I18n.locale)
        (locale.to_s == "ru" ? summary_ru : summary_en).presence || summary_en
      end

      def food(locale = I18n.locale)
        (locale.to_s == "ru" ? food_ru : food_en).presence || food_en
      end

      def rule_text(locale = I18n.locale)
        (locale.to_s == "ru" ? rule_ru : rule_en).presence || rule_en
      end

      def lunar?
        rule["type"] == "lunar"
      end

      def date_for(year)
        case rule["type"]
        when "lunar"
          LunarCalendar.to_gregorian(year, rule["month"], rule["day"])
        when "gregorian"
          Date.new(year, rule["month"], rule["day"])
        when "solar_term"
          solar_term_date(year)
        end

      rescue Date::Error
        nil
      end

      private

      def solar_term_date(year)
        first = LunarCalendar.first_year
        last = LunarCalendar.last_year
        return nil if first.nil? || last.nil?
        return nil unless (first..last).cover?(year)

        SolarTerms.date_for(rule["term"], year)
      end
    end

    class << self
      def all
        @all ||= raw["holidays"].map do |row|
          Entry.new(
            key: row["key"],
            traditional: row["traditional"],
            pinyin: row["pinyin"],
            aka: Array(row["aka"]),
            rule: row["rule"],
            rule_en: row["rule_en"],
            rule_ru: row["rule_ru"],
            public_holiday: row["public_holiday"],
            summary_en: row["summary_en"],
            summary_ru: row["summary_ru"],
            food_en: row["food_en"],
            food_ru: row["food_ru"],
            words: Array(row["words"]).map do |w|
              Word.new(
                traditional: w["traditional"],
                pinyin: w["pinyin"],
                zhuyin: w["zhuyin"],
                gloss_en: w["gloss_en"],
                gloss_ru: w["gloss_ru"]
              )
            end
          )
        end
      end

      def for_year(year)
        all
          .filter_map do |entry|
            date = entry.date_for(year)
            {entry: entry, date: date} if date
          end
          .sort_by { |row| row[:date] }
      end

      def word_texts
        all.flat_map { |entry| entry.words.map(&:traditional) }.uniq
      end

      def source
        raw["sources"]
      end

      def reset!
        @all = nil
        DATA.reset!
      end

      private

      def raw = DATA.value
    end
  end
end
