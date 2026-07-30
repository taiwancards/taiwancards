# frozen_string_literal: true

module Huayu
  module ZhuyinKeyboard
    KEYS = {
      "1" => "ㄅ",
      "q" => "ㄆ",
      "a" => "ㄇ",
      "z" => "ㄈ",
      "2" => "ㄉ",
      "w" => "ㄊ",
      "s" => "ㄋ",
      "x" => "ㄌ",
      "e" => "ㄍ",
      "d" => "ㄎ",
      "c" => "ㄏ",
      "r" => "ㄐ",
      "f" => "ㄑ",
      "v" => "ㄒ",
      "5" => "ㄓ",
      "t" => "ㄔ",
      "g" => "ㄕ",
      "b" => "ㄖ",
      "y" => "ㄗ",
      "h" => "ㄘ",
      "n" => "ㄙ",
      "u" => "ㄧ",
      "j" => "ㄨ",
      "m" => "ㄩ",
      "8" => "ㄚ",
      "i" => "ㄛ",
      "k" => "ㄜ",
      "," => "ㄝ",
      "9" => "ㄞ",
      "o" => "ㄟ",
      "l" => "ㄠ",
      "." => "ㄡ",
      "0" => "ㄢ",
      "p" => "ㄣ",
      ";" => "ㄤ",
      "/" => "ㄥ",
      "-" => "ㄦ"
    }.freeze

    TONE_KEYS = {"6" => "ˊ", "3" => "ˇ", "4" => "ˋ", "7" => "˙", " " => ""}.freeze

    ROWS = [
      %w[1 2 3 4 5 6 7 8 9 0 -],
      %w[q w e r t y u i o p],
      %w[a s d f g h j k l ;],
      %w[z x c v b n m , . /]
    ].freeze

    module_function

    def layout
      ROWS.map do |row|
        row.map { |key| {key:, symbol: KEYS[key], tone: TONE_KEYS[key]}.compact }
      end
    end

    def symbol_for(key)
      KEYS[key.to_s.downcase]
    end
  end
end
