# frozen_string_literal: true

module Pronunciation
  module Parts
    INITIAL_CHARS = "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ".chars.freeze
    MEDIAL_CHARS = "ㄧㄨㄩ".chars.freeze
    TONE_CHARS = "ˉˊˇˋ˙".freeze

    ZHUYIN_TO_PINYIN = {
      "ㄅ" => "b",
      "ㄆ" => "p",
      "ㄇ" => "m",
      "ㄈ" => "f",
      "ㄉ" => "d",
      "ㄊ" => "t",
      "ㄋ" => "n",
      "ㄌ" => "l",
      "ㄍ" => "g",
      "ㄎ" => "k",
      "ㄏ" => "h",
      "ㄐ" => "j",
      "ㄑ" => "q",
      "ㄒ" => "x",
      "ㄓ" => "zh",
      "ㄔ" => "ch",
      "ㄕ" => "sh",
      "ㄖ" => "r",
      "ㄗ" => "z",
      "ㄘ" => "c",
      "ㄙ" => "s",
      "ㄚ" => "a",
      "ㄛ" => "o",
      "ㄜ" => "e",
      "ㄝ" => "ê",
      "ㄞ" => "ai",
      "ㄟ" => "ei",
      "ㄠ" => "ao",
      "ㄡ" => "ou",
      "ㄢ" => "an",
      "ㄣ" => "en",
      "ㄤ" => "ang",
      "ㄥ" => "eng",
      "ㄦ" => "er",
      "ㄧ" => "i",
      "ㄨ" => "u",
      "ㄩ" => "ü"
    }.freeze

    IPA = {
      "ㄅ" => "p",
      "ㄆ" => "pʰ",
      "ㄇ" => "m",
      "ㄈ" => "f",
      "ㄉ" => "t",
      "ㄊ" => "tʰ",
      "ㄋ" => "n",
      "ㄌ" => "l",
      "ㄍ" => "k",
      "ㄎ" => "kʰ",
      "ㄏ" => "x",
      "ㄐ" => "tɕ",
      "ㄑ" => "tɕʰ",
      "ㄒ" => "ɕ",
      "ㄓ" => "ʈʂ",
      "ㄔ" => "ʈʂʰ",
      "ㄕ" => "ʂ",
      "ㄖ" => "ʐ",
      "ㄗ" => "ts",
      "ㄘ" => "tsʰ",
      "ㄙ" => "s",
      "ㄚ" => "a",
      "ㄛ" => "wo",
      "ㄜ" => "ɤ",
      "ㄝ" => "ɛ",
      "ㄞ" => "ai̯",
      "ㄟ" => "ei̯",
      "ㄠ" => "ɑu̯",
      "ㄡ" => "ou̯",
      "ㄢ" => "an",
      "ㄣ" => "ən",
      "ㄤ" => "ɑŋ",
      "ㄥ" => "əŋ",
      "ㄦ" => "ɚ",
      "ㄧ" => "i",
      "ㄨ" => "u",
      "ㄩ" => "y"
    }.freeze

    MEDIAL_IPA = {"ㄧ" => "j", "ㄨ" => "w", "ㄩ" => "ɥ"}.freeze

    EMPTY_RIME = "空韻"
    RETROFLEX_EMPTY = %w[ㄓ ㄔ ㄕ ㄖ].freeze

    module_function

    def split(zhuyin)
      chars = zhuyin.to_s.delete(TONE_CHARS).strip.chars
      initial = INITIAL_CHARS.include?(chars.first) ? chars.shift : nil
      medial = (chars.length > 1 && MEDIAL_CHARS.include?(chars.first)) ? chars.shift : nil
      [initial, medial, chars.join.presence]
    end

    def describe(zhuyin)
      initial, medial, rime = split(zhuyin)

      [
        part("initial", initial),
        part("medial", medial, ipa: medial && MEDIAL_IPA[medial]),
        rime_part(initial, rime)
      ]
    end

    def part(id, symbol, ipa: nil)
      return {"id" => id, "present" => false} if symbol.nil?

      {
        "id" => id,
        "present" => true,
        "zhuyin" => symbol,
        "pinyin" => ZHUYIN_TO_PINYIN[symbol],
        "ipa" => ipa || IPA[symbol]
      }
    end

    def rime_part(initial, rime)
      return part("final", rime) if rime

      {
        "id" => "final",
        "present" => true,
        "zhuyin" => EMPTY_RIME,
        "pinyin" => "-i",
        "ipa" => RETROFLEX_EMPTY.include?(initial) ? "ɻ̩" : "ɹ̩",
        "empty_rime" => true
      }
    end
  end
end
