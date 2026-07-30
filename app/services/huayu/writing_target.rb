# frozen_string_literal: true

module Huayu
  class WritingTarget
    HAN = /\p{Han}/

    def self.writable?(text)
      han = text.to_s.chars.select { |char| char.match?(HAN) }
      han.any? && han.all? { |char| Huayu::StrokeData.has?(char) }
    end

    def initialize(lexeme)
      @lexeme = lexeme
    end

    def chars
      syllables = Huayu::Zhuyin.syllabify(pinyin) || []
      han_index = -1
      @lexeme.text.chars.filter_map do |char|
        next unless char.match?(HAN)

        han_index += 1
        part = syllables[han_index] || {}
        {
          "char" => char,
          "pinyin" => part["pinyin"],
          "zhuyin" => part["zhuyin"],
          "strokes" => Huayu::StrokeData.has?(char)
        }
      end
    end

    def writable?
      self.class.writable?(@lexeme.text)
    end

    private

    def pinyin
      @lexeme.readings["pinyin"].presence || @lexeme.reading_set.first&.dig("pinyin")
    end
  end
end
