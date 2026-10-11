# frozen_string_literal: true

module Huayu
  class PronunciationTarget
    def initialize(lexeme)
      @lexeme = lexeme
    end

    def syllables
      TextReading.rows(
        @lexeme.text,
        stored_reading.presence || assembled_reading,
        words: (segments if @lexeme.sentence?)
      )
    end

    private

    def stored_reading
      TextReading.headline(@lexeme.readings["pinyin"].presence || @lexeme.reading_set.first&.dig("pinyin"))
    end

    def assembled_reading
      return nil unless @lexeme.sentence?

      TextReading.new(lexemes: lexemes_of(segments)).spell(segments)
    end

    def segments
      @segments ||= begin
        stored = @lexeme.data["segments"]
        (stored.is_a?(Array) && stored.any?) ? stored : Huayu::TextAnalyzer.new.segment(@lexeme.text)
      end
    end

    def lexemes_of(units) = SpokenReading.lexemes_for(units + @lexeme.text.scan(TextReading::HAN))
  end
end
