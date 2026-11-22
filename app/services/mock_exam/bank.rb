# frozen_string_literal: true

module MockExam
  class Bank
    LEVELS = %w[Novice1 Novice2 A1 A2 B1].freeze
    FORMATS = %w[sentence sign paragraph cloze passage].freeze
    FILES = LEVELS.index_with { |level| "huayu/exam/#{level.downcase}.json" }.freeze
    SLUGS = Regexp.union(LEVELS.map { |level| level.downcase })
    GAP = "＿＿＿"
    SLOTS = %w[① ② ③ ④ ⑤ ⑥].freeze

    Sign = Data.define(:style, :title, :lines, :foot)

    Question = Data.define(:slot, :ask, :options, :answer, :names, :notes) do
      def ask_name(locale) = Locales.pick(names, locale)

      def note(locale) = Locales.pick(notes, locale)

      def key = options[answer]
    end

    Block = Data.define(:id, :level, :format, :text, :names, :sign, :questions) do
      def name(locale) = Locales.pick(names, locale)

      def size = questions.size

      def sign? = format == "sign"

      def position = FORMATS.index(format) || FORMATS.size
    end

    class << self
      def levels = LEVELS.select { |level| blocks(level).any? }

      def slug(level) = level.to_s.downcase

      def find(slug) = LEVELS.find { |level| slug(level) == slug.to_s.downcase }

      def formats(level) = blocks(level).map(&:format).uniq.sort_by { |format| FORMATS.index(format) }

      def blocks(level) = payload.fetch(level.to_s, [])

      def all = LEVELS.flat_map { |level| blocks(level) }

      def questions(level) = blocks(level).sum(&:size)

      def choices(level) = level.to_s == "Novice1" || level.to_s == "Novice2" ? 3 : 4

      def reset! = @payload = nil

      private

      def payload
        @payload ||= FILES.transform_values { |file| read(file) }
      end

      def read(file)
        path = AppData.path(file)
        return [] unless path.exist?

        raw = JSON.parse(path.read)
        raw.fetch("blocks", []).map { |block| build(raw.fetch("level"), block) }
      end

      def build(level, raw)
        Block.new(
          id: raw.fetch("id"),
          level: level,
          format: raw.fetch("format"),
          text: raw["zh"].to_s,
          names: raw.slice(*Locales::STORED),
          sign: raw["sign"] && sign(raw["sign"]),
          questions: raw.fetch("questions", []).each_with_index.map { |question, index| question(question, index) }
        )
      end

      def sign(raw)
        Sign.new(
          style: raw.fetch("style", "notice"),
          title: raw["title"].to_s,
          lines: raw.fetch("lines", []),
          foot: raw["foot"].presence
        )
      end

      def question(raw, index)
        Question.new(
          slot: SLOTS[index],
          ask: raw["ask"].to_s,
          options: raw.fetch("options"),
          answer: raw.fetch("answer").to_i,
          names: raw.slice(*Locales::STORED),
          notes: Locales::STORED.to_h { |key| [key, raw["why_#{key}"]] }.compact_blank
        )
      end
    end
  end
end
