# frozen_string_literal: true

module Huayu
  class TocflPapers
    DATA = JsonData.new("huayu/tocfl_papers.json", default: {}, watch: true)

    BANDS = %w[Novice A B C].freeze
    SKILLS = %w[listening reading].freeze
    LETTERS = %w[A B C D E F].freeze

    Paper = Data.define(:slug, :band, :set, :level, :skill, :audio, :answers, :count) do
      def to_param = slug

      def listening? = skill == "listening"

      def numbers = (1..count).to_a

      def answer(number) = answers[number.to_s]

      def mark(given)
        numbers.count { |number| (expected = answer(number)) && given[number] == expected }
      end

      def label = "#{band} · #{I18n.t("exams.set", number: set)}"
    end

    class << self
      def all = payload

      def find(slug) = payload.find { |paper| paper.slug == slug.to_s }

      def by_band = payload.group_by(&:band)

      def reset!
        DATA.reset!
        remove_instance_variable(:@payload) if defined?(@payload)
        @rows = nil
      end

      private

      def payload
        rows = DATA.value
        return @payload if defined?(@payload) && @rows.equal?(rows)

        @rows = rows
        @payload = Array(rows["papers"])
          .map do |row|
            Paper.new(
              slug: row["slug"],
              band: row["band"],
              set: row["set"].to_i,
              level: row["level"],
              skill: row["skill"],
              audio: row["audio"],
              answers: row["answers"] || {},
              count: row["count"].to_i
            )
          end
          .freeze
      end
    end
  end
end
