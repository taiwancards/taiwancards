# frozen_string_literal: true

module Huayu
  class SentenceTemplate
    DIGITS = /[0-9０-９一二三四五六七八九十百千萬零壹貳參肆伍陸柒捌玖拾佰仟]+/
    TAIL = 10
    MIN_TAIL_LENGTH = TAIL + 2

    class << self
      def tail_key(text)
        han = text.to_s.scan(/\p{Han}/)
        return nil if han.length < MIN_TAIL_LENGTH

        han.last(TAIL).join
      end

      def digit_key(text)
        return nil unless text.to_s.match?(DIGITS)

        text.to_s.gsub(DIGITS, "#")
      end
    end
  end
end
