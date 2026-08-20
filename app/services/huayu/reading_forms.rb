# frozen_string_literal: true

module Huayu
  module ReadingForms
    module_function

    ZHUYIN_TONES = "ˊˇˋ˙"
    BOPOMOFO = /[ㄅ-ㄯㆠ-ㆿ]/

    MARKED_VOWELS = Zhuyin::TONED_VOWELS
      .each_with_object({}) do |(marked, (base, tone)), acc|
        acc[[base, tone]] = marked
      end
      .freeze

    def marked_pinyin(syllable, tone)
      body = syllable.to_s.chars.map { |char| Zhuyin::TONED_VOWELS[char]&.first || char }.join
      return body if tone.nil? || tone.zero? || tone == 5

      index = tone_vowel_index(body)
      return body if index.nil?

      marked = MARKED_VOWELS[[body[index], tone]]
      marked ? body.dup.tap { |out| out[index] = marked } : body
    end

    def tone_vowel_index(body)
      return body.index("a") if body.include?("a")
      return body.index("o") if body.include?("o")
      return body.index("e") if body.include?("e")

      body.rindex(/[iuü]/)
    end

    def plain_pinyin(pinyin)
      pinyin
        .to_s
        .chars
        .map { |char| Zhuyin::TONED_VOWELS[char]&.first || char }
        .join
        .downcase
        .gsub(/[^a-zü]/, "")
        .tr("ü", "v")
    end

    def numbered_pinyin(pinyin)
      syllables = Zhuyin.syllabify(pinyin)
      return fallback_numbered(pinyin) if syllables.nil?

      syllables.map { |syllable| numbered_syllable(syllable["pinyin"]) }.join
    end

    def fallback_numbered(pinyin)
      pinyin.to_s.split(/[\s'·]+/).map { |syllable| numbered_syllable(syllable) }.join
    end

    def numbered_syllable(syllable)
      tone = 0
      body = syllable
        .chars
        .map do |char|
          base, mark = Zhuyin::TONED_VOWELS[char]
          if base
            tone = mark if mark && mark > 0
            base
          else
            char
          end
        end
        .join
        .downcase
        .gsub(/[^a-zü]/, "")
        .tr("ü", "v")
      return "" if body.empty?

      "#{body}#{tone.zero? ? 5 : tone}"
    end

    def normalize_zhuyin(zhuyin)
      zhuyin.to_s.gsub(/[[:space:]]+/, " ").strip
    end

    def plain_zhuyin(zhuyin)
      zhuyin.to_s.delete(ZHUYIN_TONES).gsub(/[[:space:]]+/, "")
    end

    def toned_zhuyin(zhuyin)
      zhuyin.to_s.gsub(/[[:space:]]+/, "")
    end

    def bopomofo?(text)
      text.to_s.match?(BOPOMOFO)
    end

    HAN_ONLY = /\A\p{Han}+\z/
    ERHUA = "兒"

    def syllables(zhuyin)
      zhuyin.to_s.split(/[[:space:]　]+/).count(&:present?)
    end

    def malformed?(text, zhuyin)
      return false unless text.to_s.match?(HAN_ONLY)

      counted = syllables(zhuyin)
      return false if counted.zero?

      accepted = [text.length]
      accepted << text.length - 1 if text.end_with?(ERHUA)
      accepted.exclude?(counted)
    end

    def reading_terms(pinyin, zhuyin)
      [
        pinyin.to_s.downcase.gsub(/[[:space:]]+/, ""),
        plain_pinyin(pinyin),
        numbered_pinyin(pinyin),
        toned_zhuyin(zhuyin),
        plain_zhuyin(zhuyin)
      ]
    end

    READING_MARK = "="
    COMBINING = /\p{Mn}/

    def reading_token(form)
      "#{READING_MARK}#{form}"
    end

    def unmarked(text)
      text.to_s.unicode_normalize(:nfd).gsub(COMBINING, "")
    end

    def latin_letters(text)
      unmarked(text).downcase.gsub(/[^a-z]/, "")
    end

    def romanized_terms(romanization)
      text = romanization.to_s.downcase.strip
      return [] if text.blank?

      [text, text.delete("-"), unmarked(text), latin_letters(text)].compact_blank.uniq
    end

    def hokkien_terms(hokkien)
      return [] unless hokkien.is_a?(Hash)

      say = hokkien["say"]
      spoken = say.is_a?(Hash) ? reading_terms(say["pinyin"], say["zhuyin"]) : []
      (spoken + romanized_terms(hokkien["tailo"])).compact_blank.uniq
    end

    def search_bag(text:, readings:, meanings:, hokkien: nil)
      terms = [text]
      Array(readings).each do |reading|
        pinyin = reading["pinyin"].to_s
        zhuyin = reading["zhuyin"].to_s
        next if pinyin.blank? && zhuyin.blank?

        terms.concat(reading_terms(pinyin, zhuyin).compact_blank.map { |form| reading_token(form) })
      end

      terms.concat(hokkien_terms(hokkien).map { |form| reading_token(form) })

      Array(meanings).each { |meaning| terms << meaning.to_s.downcase.gsub(%r{[;,/()\[\].!?]+}, " ") }
      terms.map(&:strip).reject(&:blank?).uniq.join(" ")
    end
  end
end
