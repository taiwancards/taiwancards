# frozen_string_literal: true

module Huayu
  class Holidays
    DATA = JsonData.new("huayu/holidays.json", default: {"holidays" => [], "sources" => []})

    Word = Data.define(:traditional, :pinyin, :zhuyin, :glosses) do
      def gloss(locale = I18n.locale) = Locales.pick(glosses, locale)
    end

    Entry = Data.define(
      :key,
      :traditional,
      :pinyin,
      :aka,
      :rule,
      :rules,
      :public_holiday,
      :summaries,
      :foods,
      :words
    ) do
      def summary(locale = I18n.locale) = Locales.pick(summaries, locale)

      def food(locale = I18n.locale) = Locales.pick(foods, locale)

      def rule_text(locale = I18n.locale) = Locales.pick(rules, locale)

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
            rules: localized(row, "rule"),
            public_holiday: row["public_holiday"],
            summaries: localized(row, "summary"),
            foods: localized(row, "food"),
            words: Array(row["words"]).map do |w|
              Word.new(
                traditional: w["traditional"],
                pinyin: w["pinyin"],
                zhuyin: w["zhuyin"],
                glosses: localized(w, "gloss")
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

      def localized(row, field) = Locales::ALL.to_h { |code| [code, row["#{field}_#{code}"]] }
    end
  end
end
