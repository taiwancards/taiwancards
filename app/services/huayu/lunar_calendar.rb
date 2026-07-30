# frozen_string_literal: true

module Huayu
  class LunarCalendar
    DATA_PATH = AppData.path("huayu/lunar_years.json")

    DAY_PREFIXES = %w[初 十 廿 卅].freeze
    DAY_DIGITS = %w[一 二 三 四 五 六 七 八 九 十].freeze
    MONTH_NAMES = %w[正 二 三 四 五 六 七 八 九 十 十一 十二].freeze

    Year = Data.define(:year, :new_year, :leap_month, :month_lengths) do
      def months
        seq = []
        (1..12).each do |n|
          seq << [n, false]
          seq << [n, true] if n == leap_month
        end

        seq.each_with_index.map { |(n, leap), i| {number: n, leap: leap, length: month_lengths[i]} }
      end

      def length
        month_lengths.sum
      end

      def last_date
        new_year + length - 1
      end
    end

    class << self
      def years
        @years ||= raw["years"].to_h do |row|
          year = Year.new(
            year: row["year"],
            new_year: Date.parse(row["new_year"]),
            leap_month: row["leap_month"],
            month_lengths: row["month_lengths"]
          )
          [row["year"], year]
        end
      end

      def source
        raw["source"]
      end

      def available?
        raw["range"].present?
      end

      def first_year
        raw["range"].to_a.first
      end

      def last_year
        raw["range"].to_a.last
      end

      def min_date
        return nil unless available?

        years[first_year].new_year
      end

      def max_date
        return nil unless available?

        years[last_year].last_date
      end

      def covers?(date)
        return false unless available?

        date >= min_date && date <= max_date
      end

      def to_gregorian(year, month, day, leap: false)
        entry = years[year]
        return nil if entry.nil?

        offset = 0
        entry.months.each do |m|
          if m[:number] == month && m[:leap] == leap
            return nil if day < 1 || day > m[:length]

            return entry.new_year + offset + day - 1
          end

          offset += m[:length]
        end

        nil
      end

      def to_lunar(date)
        return nil unless covers?(date)

        year = date.year
        year -= 1 while years[year].nil? || date < years[year].new_year
        entry = years[year]
        offset = (date - entry.new_year).to_i

        entry.months.each do |m|
          return {year: year, month: m[:number], day: offset + 1, leap: m[:leap]} if offset < m[:length]

          offset -= m[:length]
        end

        nil
      end

      def leap_years
        years.values.select { |y| y.leap_month.positive? }
      end

      def day_label(day)
        return "#{DAY_PREFIXES[(day - 1) / 10]}#{DAY_DIGITS[(day - 1) % 10]}" unless (day % 10).zero?

        case day
        when 10
          "初十"
        when 20
          "二十"
        when 30
          "三十"
        end
      end

      def month_label(month, leap: false)
        "#{leap ? "閏" : ""}#{MONTH_NAMES[month - 1]}月"
      end

      def payload
        years.values.map do |y|
          {y: y.year, n: y.new_year.strftime("%Y-%m-%d"), l: y.leap_month, m: y.month_lengths}
        end
      end

      def reset!
        @years = nil
        @raw = nil
      end

      private

      def raw
        @raw ||= begin
          JSON.parse(File.read(DATA_PATH))
        rescue Errno::ENOENT, JSON::ParserError => e
          Rails.logger.error("lunar calendar data unavailable at #{DATA_PATH}: #{e.class}: #{e.message}")
          {"years" => [], "range" => []}
        end
      end
    end
  end
end
