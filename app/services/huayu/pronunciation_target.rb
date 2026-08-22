# frozen_string_literal: true

module Huayu
  class PronunciationTarget
    def initialize(lexeme)
      @lexeme = lexeme
    end

    def syllables
      TextReading.rows(@lexeme.text, stored_reading.presence || assembled_reading)
    end

    private

    def stored_reading
      TextReading.headline(@lexeme.readings["pinyin"].presence || @lexeme.reading_set.first&.dig("pinyin"))
    end

    def assembled_reading
      return nil unless @lexeme.sentence?

      TextReading.new(index: readings_of(segments)).spell(segments)
    end

    def segments
      @segments ||= begin
        stored = @lexeme.data["segments"]
        (stored.is_a?(Array) && stored.any?) ? stored : Huayu::TextAnalyzer.new.segment(@lexeme.text)
      end
    end

    def readings_of(units)
      texts = (units + @lexeme.text.scan(TextReading::HAN)).uniq
      Lexeme
        .where(kind: Huayu::TextAnalyzer::TOKEN_KINDS, text: texts)
        .order(:kind)
        .each_with_object({}) { |lexeme, acc| acc[lexeme.text] ||= lexeme.readings["pinyin"] }
    end
  end
end
