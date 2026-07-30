# frozen_string_literal: true

module Sentences
  class Breakdown
    Word = Data.define(:text, :lexeme, :senses, :known)
    Character = Data.define(:text, :lexeme, :level, :grade, :rank)

    Result = Data.define(:words, :characters, :unknown_count)

    def initialize(sentence)
      @sentence = sentence
    end

    def call
      words = build_words(segments)
      Result.new(
        words: words,
        characters: build_characters,
        unknown_count: words.count { |word| word.lexeme.nil? }
      )
    end

    private

    def segments
      stored = @sentence.data["segments"]
      return stored if stored.is_a?(Array) && stored.any?

      Huayu::TextAnalyzer.new.segment(@sentence.text)
    end

    def build_words(units)
      texts = units.uniq
      lexemes = Lexeme
        .where(kind: %i[word character], text: texts)
        .includes(senses: :examples)
        .index_by(&:text)

      units.map do |unit|
        lexeme = lexemes[unit]
        Word.new(
          text: unit,
          lexeme: lexeme,
          senses: lexeme ? lexeme.senses.to_a : [],
          known: lexeme.present?
        )
      end
    end

    def build_characters
      texts = @sentence.text.scan(/\p{Han}/).uniq
      lexemes = Lexeme.where(kind: :character, text: texts).index_by(&:text)

      texts
        .map do |text|
          lexeme = lexemes[text]
          Character.new(
            text: text,
            lexeme: lexeme,
            level: lexeme&.data&.dig("tocfl_level"),
            grade: lexeme&.data&.dig("tbcl_grade")&.to_i,
            rank: lexeme&.data&.dig("freq_rank")&.to_i
          )
        end
        .sort_by { |char| [level_index(char.level), char.grade || 99, char.rank&.positive? ? char.rank : 999_999] }
    end

    LEVELS = %w[Novice1 Novice2 A1 A2 B1 B2 C].freeze

    def level_index(level)
      LEVELS.index(level) || 99
    end
  end
end
