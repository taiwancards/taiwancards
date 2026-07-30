# frozen_string_literal: true

module Liangci
  class Sidecar
    EXAMPLE_LIMIT = 3

    Result = Data.define(:measure_word, :classifiers, :examples) do
      def any?
        measure_word.present? || classifiers.any?
      end
    end

    def call(lexeme)
      rows = Array(lexeme.data["classifiers"])
      Result.new(
        measure_word: Lexeme.find_by(kind: :measure_word, text: lexeme.text),
        classifiers: entries(rows),
        examples: examples(lexeme, rows)
      )
    end

    private

    def entries(rows)
      return [] if rows.empty?

      found = Lexeme.where(kind: :measure_word, text: rows.map { |row| row["text"] }).index_by(&:text)
      rows.filter_map do |row|
        entry = found[row["text"]]
        {entry:, main: row["main"]} if entry
      end
    end

    def examples(lexeme, rows)
      return [] if rows.empty?

      pairs = rows.map { |row| [row["text"], lexeme.text] }
      Huayu::ClassifierExamples.new.for_pairs(pairs, limit: EXAMPLE_LIMIT)
    end
  end
end
