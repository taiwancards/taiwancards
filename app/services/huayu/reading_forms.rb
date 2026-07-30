# frozen_string_literal: true

module Huayu
  module ReadingForms
    module_function

    ZHUYIN_TONES = "ˊˇˋ˙"
    BOPOMOFO = /[ㄅ-ㄯㆠ-ㆿ]/

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

    def reading_token(form)
      "#{READING_MARK}#{form}"
    end

    def search_bag(text:, readings:, meanings:)
      terms = [text]
      Array(readings).each do |reading|
        pinyin = reading["pinyin"].to_s
        zhuyin = reading["zhuyin"].to_s
        next if pinyin.blank? && zhuyin.blank?

        terms.concat(reading_terms(pinyin, zhuyin).compact_blank.map { |form| reading_token(form) })
      end

      Array(meanings).each { |meaning| terms << meaning.to_s.downcase.gsub(%r{[;,/()\[\].!?]+}, " ") }
      terms.map(&:strip).reject(&:blank?).uniq.join(" ")
    end
  end
end
