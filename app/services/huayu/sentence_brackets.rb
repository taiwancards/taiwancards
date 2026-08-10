# frozen_string_literal: true

module Huayu
  class SentenceBrackets
    PAIRS = {
      "（" => "）",
      "(" => ")",
      "「" => "」",
      "『" => "』",
      "《" => "》",
      "〈" => "〉",
      "【" => "】",
      "〔" => "〕",
      "［" => "］",
      "[" => "]"
    }.freeze
    CLOSERS = PAIRS.invert.freeze
    FILLER = "[[:space:]、，,;；・·．.]*"
    EMPTY = Regexp
      .union(
        PAIRS.map { |open, close| /#{Regexp.escape(open)}#{FILLER}#{Regexp.escape(close)}/ }
      )
      .freeze
    SQL_EMPTY = PAIRS
      .map { |open, close| "#{Regexp.escape(open)}#{FILLER}#{Regexp.escape(close)}" }
      .join("|")
      .freeze
    SEPARATORS = "，、"
    TRAILING = "。！？；："

    class << self
      def hollow?(text)
        text.to_s.match?(EMPTY)
      end

      def residue?(text)
        hollow?(text) || unbalanced?(text)
      end

      def beheaded?(text)
        text.to_s.match?(/\A#{EMPTY}/o)
      end

      def unbalanced?(text)
        stack = []

        text.to_s.each_char do |char|
          next stack.push(char) if PAIRS.key?(char)
          next unless CLOSERS.key?(char)
          return true unless stack.last == CLOSERS[char]

          stack.pop
        end

        stack.any?
      end

      def clean(text)
        SentenceText.trim(tidy(drop_unmatched(drop_empty(text.to_s))))
      end

      private

      def drop_empty(text)
        previous = nil
        while text != previous
          previous = text
          text = text.gsub(EMPTY, "")
        end

        text
      end

      def drop_unmatched(text)
        stack = []
        doomed = Set.new

        text.each_char.with_index do |char, index|
          next stack.push([char, index]) if PAIRS.key?(char)
          next unless CLOSERS.key?(char)

          if stack.last&.first == CLOSERS[char]
            stack.pop
          else
            doomed << index
          end
        end

        stack.each { |_, index| doomed << index }
        return text if doomed.empty?

        text.each_char.with_index.filter_map { |char, index| char unless doomed.include?(index) }.join
      end

      def tidy(text)
        text
          .gsub(/[#{SEPARATORS}]{2,}/o, "，")
          .gsub(/[#{SEPARATORS}]+(?=[#{TRAILING}])/o, "")
          .gsub(/\A[#{SEPARATORS}#{TRAILING}]+/o, "")
      end
    end
  end
end
