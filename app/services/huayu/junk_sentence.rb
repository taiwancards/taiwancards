# frozen_string_literal: true

module Huayu
  class JunkSentence
    MIN_LENGTH = 4
    SHORT_ENOUGH = 20
    MIN_VARIETY = 0.34
    MIN_RUN = 4
    RUN_SHARE = 0.4
    BROKEN_GLYPH = /[\u{E000}-\u{F8FF}\u{F0000}-\u{FFFFD}\u{100000}-\u{10FFFD}]/
    DANGLING_HEAD = %w[的 之 及 或 與 暨 者 至].freeze
    DANGLING_TAIL = %w[及 或 與 暨 為 由].freeze
    FRAGMENT_LENGTH = 12

    class << self
      def rejects?(text, words: nil)
        return true if text.to_s.match?(BROKEN_GLYPH)

        han = text.to_s.scan(/\p{Han}/)
        return false if han.length < MIN_LENGTH

        return true if han.uniq.length <= 2
        return true if han.length <= SHORT_ENOUGH && (han.uniq.length.to_f / han.length) <= MIN_VARIETY
        return true if fragment?(han, words)

        run = longest_run(text)
        run >= MIN_RUN && (run.to_f / han.length) >= RUN_SHARE
      end

      private

      def fragment?(han, words)
        return false unless words.is_a?(Array) && words.any?
        return true if DANGLING_HEAD.include?(words.first)

        han.length <= FRAGMENT_LENGTH && DANGLING_TAIL.include?(words.last)
      end

      def longest_run(text)
        text.to_s.enum_for(:scan, /(\p{Han})\1*/).map { Regexp.last_match(0).length }.max.to_i
      end
    end
  end
end
