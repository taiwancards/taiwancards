# frozen_string_literal: true

module Huayu
  module Cangjie
    KEYS = {
      "a" => "日",
      "b" => "月",
      "c" => "金",
      "d" => "木",
      "e" => "水",
      "f" => "火",
      "g" => "土",
      "h" => "竹",
      "i" => "戈",
      "j" => "十",
      "k" => "大",
      "l" => "中",
      "m" => "一",
      "n" => "弓",
      "o" => "人",
      "p" => "心",
      "q" => "手",
      "r" => "口",
      "s" => "尸",
      "t" => "廿",
      "u" => "山",
      "v" => "女",
      "w" => "田",
      "x" => "難",
      "y" => "卜",
      "z" => "重"
    }.freeze

    ROWS = [%w[q w e r t y u i o p], %w[a s d f g h j k l], %w[z x c v b n m]].freeze

    module_function

    def radicals(code)
      code.to_s.downcase.chars.map { |letter| KEYS[letter] }.compact.join
    end
  end
end
