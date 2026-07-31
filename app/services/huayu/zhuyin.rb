# frozen_string_literal: true

module Huayu
  module Zhuyin
    TONED_VOWELS = {
      "ā" => ["a", 1],
      "á" => ["a", 2],
      "ǎ" => ["a", 3],
      "à" => ["a", 4],
      "ē" => ["e", 1],
      "é" => ["e", 2],
      "ě" => ["e", 3],
      "è" => ["e", 4],
      "ī" => ["i", 1],
      "í" => ["i", 2],
      "ǐ" => ["i", 3],
      "ì" => ["i", 4],
      "ō" => ["o", 1],
      "ó" => ["o", 2],
      "ǒ" => ["o", 3],
      "ò" => ["o", 4],
      "ū" => ["u", 1],
      "ú" => ["u", 2],
      "ǔ" => ["u", 3],
      "ù" => ["u", 4],
      "ǖ" => ["ü", 1],
      "ǘ" => ["ü", 2],
      "ǚ" => ["ü", 3],
      "ǜ" => ["ü", 4],
      "ê" => ["ê", 0],
      "ế" => ["ê", 2],
      "ề" => ["ê", 4]
    }.freeze

    INITIALS = {
      "zh" => "ㄓ",
      "ch" => "ㄔ",
      "sh" => "ㄕ",
      "b" => "ㄅ",
      "p" => "ㄆ",
      "m" => "ㄇ",
      "f" => "ㄈ",
      "d" => "ㄉ",
      "t" => "ㄊ",
      "n" => "ㄋ",
      "l" => "ㄌ",
      "g" => "ㄍ",
      "k" => "ㄎ",
      "h" => "ㄏ",
      "j" => "ㄐ",
      "q" => "ㄑ",
      "x" => "ㄒ",
      "r" => "ㄖ",
      "z" => "ㄗ",
      "c" => "ㄘ",
      "s" => "ㄙ"
    }.freeze

    FINALS = {
      "a" => "ㄚ",
      "o" => "ㄛ",
      "e" => "ㄜ",
      "ê" => "ㄝ",
      "ai" => "ㄞ",
      "ei" => "ㄟ",
      "ao" => "ㄠ",
      "ou" => "ㄡ",
      "an" => "ㄢ",
      "en" => "ㄣ",
      "ang" => "ㄤ",
      "eng" => "ㄥ",
      "ong" => "ㄨㄥ",
      "er" => "ㄦ",
      "i" => "ㄧ",
      "ia" => "ㄧㄚ",
      "io" => "ㄧㄛ",
      "ie" => "ㄧㄝ",
      "iai" => "ㄧㄞ",
      "iao" => "ㄧㄠ",
      "iu" => "ㄧㄡ",
      "ian" => "ㄧㄢ",
      "in" => "ㄧㄣ",
      "iang" => "ㄧㄤ",
      "ing" => "ㄧㄥ",
      "iong" => "ㄩㄥ",
      "u" => "ㄨ",
      "ua" => "ㄨㄚ",
      "uo" => "ㄨㄛ",
      "uai" => "ㄨㄞ",
      "ui" => "ㄨㄟ",
      "uan" => "ㄨㄢ",
      "un" => "ㄨㄣ",
      "uang" => "ㄨㄤ",
      "ueng" => "ㄨㄥ",
      "ü" => "ㄩ",
      "üe" => "ㄩㄝ",
      "üan" => "ㄩㄢ",
      "ün" => "ㄩㄣ"
    }.freeze

    STANDALONE = {
      "yi" => "ㄧ",
      "ya" => "ㄧㄚ",
      "yo" => "ㄧㄛ",
      "ye" => "ㄧㄝ",
      "yai" => "ㄧㄞ",
      "yao" => "ㄧㄠ",
      "you" => "ㄧㄡ",
      "yan" => "ㄧㄢ",
      "yin" => "ㄧㄣ",
      "yang" => "ㄧㄤ",
      "ying" => "ㄧㄥ",
      "yong" => "ㄩㄥ",
      "wu" => "ㄨ",
      "wa" => "ㄨㄚ",
      "wo" => "ㄨㄛ",
      "wai" => "ㄨㄞ",
      "wei" => "ㄨㄟ",
      "wan" => "ㄨㄢ",
      "wen" => "ㄨㄣ",
      "wang" => "ㄨㄤ",
      "weng" => "ㄨㄥ",
      "yu" => "ㄩ",
      "yue" => "ㄩㄝ",
      "yuan" => "ㄩㄢ",
      "yun" => "ㄩㄣ",
      "a" => "ㄚ",
      "o" => "ㄛ",
      "e" => "ㄜ",
      "ê" => "ㄝ",
      "ai" => "ㄞ",
      "ei" => "ㄟ",
      "ao" => "ㄠ",
      "ou" => "ㄡ",
      "an" => "ㄢ",
      "en" => "ㄣ",
      "ang" => "ㄤ",
      "eng" => "ㄥ",
      "er" => "ㄦ",
      "zhi" => "ㄓ",
      "chi" => "ㄔ",
      "shi" => "ㄕ",
      "ri" => "ㄖ",
      "zi" => "ㄗ",
      "ci" => "ㄘ",
      "si" => "ㄙ"
    }.freeze

    UMLAUT_INITIALS = %w[j q x].freeze
    TONE_SUFFIX = {1 => "", 2 => "ˊ", 3 => "ˇ", 4 => "ˋ"}.freeze

    SYLLABLES = (STANDALONE.keys +
      INITIALS.keys.product(FINALS.keys).map(&:join) +
      UMLAUT_INITIALS.product(%w[u ue uan un]).map(&:join))
      .uniq
      .sort_by(&:length)
      .reverse
      .freeze

    module_function

    def from_pinyin(pinyin)
      return if pinyin.blank?

      chunks = pinyin.to_s.downcase.split(/[\s'’\-–—·,，]+/).reject(&:empty?)
      converted = chunks.map { |chunk| convert_chunk(chunk) }
      return if converted.any?(&:nil?)

      converted.join(" ").presence
    end

    def tone(syllable)
      return 0 if syllable.blank?

      syllable.to_s.each_char do |char|
        mapped = TONED_VOWELS[char]
        return mapped[1] if mapped
      end

      5
    end

    def syllabify(pinyin)
      return if pinyin.blank?

      chunks = pinyin.to_s.downcase.split(/[\s'’\-–—·,，]+/).reject(&:empty?)
      result = []
      chunks.each do |chunk|
        syllables = syllabify_chunk(chunk)
        return if syllables.nil?

        result.concat(syllables)
      end

      result.presence
    end

    def syllabify_chunk(chunk)
      chars = chunk.chars
      plain = chars.map { |char| (TONED_VOWELS[char] || [char]).first }.join
      return unless plain.match?(/\A[a-zêü]+\z/)

      tones = chars.each_index.filter_map { |i| [i, TONED_VOWELS[chars[i]][1]] if TONED_VOWELS[chars[i]] }.to_h
      syllables = segment(plain)
      return if syllables.nil?

      offset = 0
      syllables.map do |syllable|
        length = syllable.length
        tone = (offset...(offset + length)).filter_map { |i| tones[i] }.first
        zhuyin = syllable_to_zhuyin(syllable)
        return if zhuyin.nil?

        entry = {"pinyin" => chars[offset, length].join, "zhuyin" => apply_tone(zhuyin, tone)}
        offset += length
        entry
      end
    end

    def convert_chunk(chunk)
      plain = +""
      tones = []
      chunk.each_char do |char|
        if (vowel, tone = TONED_VOWELS[char])
          tones << [plain.length, tone]
          plain << vowel
        else
          plain << char
        end
      end

      return unless plain.match?(/\A[a-zêü]+\z/)

      syllables = segment(plain)
      return if syllables.nil?

      offset = 0
      syllables
        .map { |syllable|
          range = offset...(offset + syllable.length)
          tone = tones.find { |position, _| range.cover?(position) }&.last
          offset += syllable.length
          zhuyin = syllable_to_zhuyin(syllable)
          return if zhuyin.nil?

          apply_tone(zhuyin, tone)
        }
        .join(" ")
    end

    VOWEL_START = /\A[aoeêü]/

    def segment(plain)
      best = nil
      best_score = nil

      segmentations(plain).each do |candidate|
        score = segmentation_score(candidate)
        next unless best_score.nil? || (score <=> best_score).negative?

        best = candidate
        best_score = score
      end

      best
    end

    def segmentations(plain, depth = 0)
      return [[]] if plain.empty?
      return [] if depth > 24

      SYLLABLES.flat_map { |candidate|
        next [] if candidate.empty? || !plain.start_with?(candidate)

        segmentations(plain.delete_prefix(candidate), depth + 1).map { |rest| [candidate] + rest }
      }
    end

    def segmentation_score(syllables)
      orphans = syllables.drop(1).count { |syllable| syllable.match?(VOWEL_START) }
      [orphans, syllables.size]
    end

    def syllable_to_zhuyin(syllable)
      return STANDALONE[syllable] if STANDALONE.key?(syllable)

      initial = INITIALS.keys.find { |candidate| syllable.start_with?(candidate) }
      return if initial.nil?

      final = syllable.delete_prefix(initial)
      final = umlautize(final) if UMLAUT_INITIALS.include?(initial)
      final_zhuyin = FINALS[final]
      return if final_zhuyin.nil?

      "#{INITIALS[initial]}#{final_zhuyin}"
    end

    def umlautize(final)
      {"u" => "ü", "ue" => "üe", "uan" => "üan", "un" => "ün"}.fetch(final, final)
    end

    def apply_tone(zhuyin, tone)
      case tone
      when nil, 0, 5
        "˙#{zhuyin}"
      else
        "#{zhuyin}#{TONE_SUFFIX.fetch(tone)}"
      end
    end
  end
end
