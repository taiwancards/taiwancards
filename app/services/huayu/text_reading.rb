# frozen_string_literal: true

module Huayu
  class TextReading
    HAN = /\p{Han}/
    ALTERNATIVES = "/"

    class << self
      def rows(text, reading)
        return [] if reading.blank?

        parts = Huayu::Zhuyin.syllabify(reading) || []
        chars = text.to_s.scan(HAN)
        return [] if parts.empty? || parts.length != chars.length

        base = parts.map { |part| Huayu::Zhuyin.tone(part["pinyin"]) }
        surface = Huayu::ToneSandhi.surface_tones(chars: chars, base_tones: base)

        parts.each_with_index.map { |part, index| row(part, chars[index], base[index], surface[index]) }
      end

      def headline(value)
        pinyin = value.is_a?(Array) ? value.first : value
        pinyin.to_s.split(ALTERNATIVES).first.to_s.strip.presence
      end

      private

      def row(part, char, base_tone, surface_tone)
        tone = surface_tone || base_tone
        {
          "char" => char,
          "pinyin" => part["pinyin"],
          "zhuyin" => part["zhuyin"],
          "tone" => tone,
          "base_tone" => base_tone,
          "key" => "#{ReadingForms.plain_pinyin(part["pinyin"])}#{tone}"
        }
      end
    end

    def initialize(index: nil)
      @index = index
    end

    def spell(segments)
      units = Array(segments)
      return nil if units.empty?

      spelled = units.map { |unit| unit_reading(unit) }
      spelled.any?(&:nil?) ? nil : spelled.join(" ")
    end

    private

    def unit_reading(unit)
      direct = self.class.headline(reading_of(unit))
      return direct if direct

      letters = unit.to_s.scan(HAN).map { |char| settled_reading(char) }
      letters.any?(&:nil?) || letters.empty? ? nil : letters.join(" ")
    end

    def settled_reading(char)
      reading = reading_of(char)
      return nil if reading.is_a?(Array) && reading.length > 1
      return nil if reading.to_s.include?(ALTERNATIVES)

      self.class.headline(reading)
    end

    def reading_of(text)
      return @index[text] if @index

      lexemes[text] ||= Lexeme
        .where(kind: Huayu::TextAnalyzer::TOKEN_KINDS, text: text)
        .order(:kind)
        .first
        &.readings
        &.dig("pinyin")
    end

    def lexemes = @lexemes ||= {}
  end
end
