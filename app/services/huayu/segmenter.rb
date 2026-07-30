# frozen_string_literal: true

module Huayu
  class Segmenter
    HAN = /\p{Han}/

    def initialize(known_words)
      @words = known_words.to_set
      @max = known_words.map(&:length).max || 1
    end

    def segment(text)
      chars = text.chars
      result = []
      index = 0
      while index < chars.length
        matched = longest_match(chars, index)
        if matched
          result << matched
          index += matched.length
        else
          index += 1
        end
      end

      result
    end

    private

    def longest_match(chars, index)
      [@max, chars.length - index].min.downto(2) do |length|
        candidate = chars[index, length].join
        return candidate if @words.include?(candidate)
      end

      single = chars[index]
      single if single&.match?(HAN) && @words.include?(single)
    end
  end
end
