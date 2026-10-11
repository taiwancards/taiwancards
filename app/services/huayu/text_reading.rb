# frozen_string_literal: true

module Huayu
  class TextReading
    HAN = /\p{Han}/
    ALTERNATIVES = "/"

    class << self
      def rows(text, reading, words: nil)
        return [] if reading.blank?

        parts = Huayu::Zhuyin.syllabify(reading) || []
        chars = text.to_s.scan(HAN)
        return [] if parts.empty? || parts.length != chars.length

        base = parts.map { |part| Huayu::Zhuyin.tone(part["pinyin"]) }
        surface = Huayu::ToneSandhi.surface_tones(
          chars:,
          base_tones: base,
          phrase_starts: phrase_starts(text),
          word_ends: word_ends(words, chars.length)
        )

        parts.each_with_index.map { |part, index| row(part, chars[index], base[index], surface[index]) }
      end

      def phrase_starts(text)
        count = 0
        gap = false
        text.to_s.each_char.with_object([]) do |char, starts|
          next gap = count.positive? unless char.match?(HAN)

          starts << count if gap
          gap = false
          count += 1
        end
      end

      def word_ends(words, total)
        count = 0
        ends = Array(words).each_with_object([]) do |word, found|
          size = word.to_s.scan(HAN).length
          count += size
          found << (count - 1) if size > 1
        end

        count == total ? ends : []
      end

      def unshifted(rows)
        rows.map { |row|
          row.merge("tone" => row["base_tone"], "key" => row["key"].sub(/\d\z/, row["base_tone"].to_s))
        }
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

    def initialize(lexemes: {})
      @lexemes = lexemes.dup
    end

    def spell(segments)
      units = SpokenReading.resplit(Array(segments))
      return nil if units.empty?

      spelled = units.map { |unit| unit_reading(unit) }
      spelled.any?(&:nil?) ? nil : spelled.join(" ")
    end

    private

    def unit_reading(unit)
      text = unit.to_s.scan(HAN).join
      return nil if text.empty?

      direct = reading_of(text, standalone: true)
      return direct if direct

      load(SpokenReading.substrings(text) + text.chars)
      parts = SpokenReading.pieces(text, method(:known?)).map { |piece| settled_reading(piece) }
      parts.any?(&:nil?) ? nil : parts.join(" ")
    end

    def settled_reading(piece)
      reading = SpokenReading.pick(@lexemes[piece], standalone: piece.length > 1)&.dig("pinyin")
      return nil if reading.to_s.include?(ALTERNATIVES)

      self.class.headline(reading)
    end

    def reading_of(text, standalone:)
      load([text])
      self.class.headline(SpokenReading.pick(@lexemes[text], standalone:)&.dig("pinyin"))
    end

    def known?(text) = SpokenReading.word?(@lexemes[text])

    def load(texts)
      missing = texts.reject { |text| @lexemes.key?(text) }
      return if missing.empty?

      found = SpokenReading.lexemes_for(missing)
      missing.each { |text| @lexemes[text] = found.fetch(text, []) }
    end
  end
end
