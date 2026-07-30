# frozen_string_literal: true

module Huayu
  class PronunciationTarget
    def initialize(lexeme)
      @lexeme = lexeme
    end

    def syllables
      pinyin = @lexeme.readings["pinyin"].presence || @lexeme.reading_set.first&.dig("pinyin")
      return [] if pinyin.blank?

      parts = Huayu::Zhuyin.syllabify(pinyin) || []
      chars = @lexeme.text.chars.select { |char| char.match?(/\p{Han}/) }
      base_tones = parts.map { |part| Huayu::Zhuyin.tone(part["pinyin"]) }
      surface_tones = Huayu::ToneSandhi.surface_tones(chars:, base_tones:)

      parts.each_with_index.map do |part, index|
        tone = surface_tones[index] || base_tones[index]
        {
          "char" => chars[index],
          "pinyin" => part["pinyin"],
          "zhuyin" => part["zhuyin"],
          "tone" => tone,
          "base_tone" => base_tones[index],
          "key" => "#{ReadingForms.plain_pinyin(part["pinyin"])}#{tone}"
        }
      end
    end
  end
end
