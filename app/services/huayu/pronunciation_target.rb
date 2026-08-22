# frozen_string_literal: true

module Huayu
  class PronunciationTarget
    def initialize(lexeme)
      @lexeme = lexeme
    end

    def syllables
      pinyin = stored_reading.presence || assembled_reading
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

    private

    def stored_reading
      @lexeme.readings["pinyin"].presence || @lexeme.reading_set.first&.dig("pinyin")
    end

    def assembled_reading
      return nil unless @lexeme.sentence?

      words = Array(@lexeme.data["segments"])
      return nil if words.empty?

      by_text = Lexeme
        .where(kind: Huayu::TextAnalyzer::TOKEN_KINDS, text: words.uniq)
        .order(:kind)
        .index_by(&:text)
      spelled = words.map { |word| by_text[word]&.readings&.dig("pinyin").presence }
      return nil if spelled.any?(&:nil?)

      reading = spelled.join(" ")
      counted = Huayu::Zhuyin.syllabify(reading)&.length
      counted == @lexeme.text.scan(/\p{Han}/).length ? reading : nil
    end
  end
end
