# frozen_string_literal: true

module Huayu
  module SpokenReading
    NEUTRAL = "˙"
    WORD_KINDS = %w[word collocation measure_word].freeze
    SPLITS = {"都會" => %w[都 會]}.freeze
    DISTRICT = "區"
    COMMON_NOUN = /\A\p{Ll}/
    INSIDE_WORDS = {
      "和" => {"pinyin" => "hé", "zhuyin" => "ㄏㄜˊ"}.freeze,
      "個" => {"pinyin" => "gè", "zhuyin" => "ㄍㄜˋ"}.freeze,
      "應" => {"pinyin" => "yìng", "zhuyin" => "ㄧㄥˋ"}.freeze,
      "給" => {"pinyin" => "jǐ", "zhuyin" => "ㄐㄧˇ"}.freeze
    }.freeze

    module_function

    def lexemes_for(texts)
      Lexeme.where(kind: TextAnalyzer::TOKEN_KINDS, text: texts.uniq).order(:id).group_by(&:text)
    end

    def pick(lexemes, standalone: true)
      known = Array(lexemes).select { |lexeme| lexeme.readings["pinyin"].present? }
      return nil if known.empty?

      word = WORD_KINDS.lazy.filter_map { |kind| known.find { |lexeme| lexeme.kind == kind } }.first
      return word&.readings if known.first.text.length > 1

      character = known.find(&:character?)
      return INSIDE_WORDS[character&.text] || character&.readings || word&.readings unless standalone
      return word.readings if word&.readings&.dig("zhuyin").to_s.start_with?(NEUTRAL)

      (character || word)&.readings
    end

    def word?(lexemes)
      Array(lexemes).any? { |lexeme| lexeme.word? && lexeme.readings["pinyin"].to_s.match?(COMMON_NOUN) }
    end

    def resplit(tokens)
      tokens.each_with_index.flat_map do |token, index|
        parts = SPLITS[token]
        next [token] if parts.nil? || tokens[index + 1]&.start_with?(DISTRICT)

        parts
      end
    end

    def pieces(text, known)
      found = []
      from = 0
      while from < text.length
        size = (text.length - from).downto(2).find { |length| known.call(text[from, length]) } || 1
        found << text[from, size]
        from += size
      end

      found
    end

    def substrings(text)
      (0...text.length).flat_map { |from| (2..(text.length - from)).map { |size| text[from, size] } }
    end
  end
end
