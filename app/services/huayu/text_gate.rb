# frozen_string_literal: true

module Huayu
  class TextGate
    Verdict = Data.define(:ok, :tier, :reason, :offender) do
      def ok? = ok

      def rejected? = !ok
    end

    HAN = /\p{Han}/
    LATIN = /[A-Za-z0-9]/

    PUNCTUATION = "。，、；：？！「」『』（）〈〉《》—…⋯‧．·　 " \
      ".,;:?!()\"'’‘-/%"

    class << self
      def instance = @instance ||= new

      def reset! = @instance = nil

      delegate :call, :ok?, :tier_of, to: :instance
    end

    def initialize
      @punctuation = PUNCTUATION.chars.to_set
      @tiers = CharacterTiers.instance
      @mainland = MainlandGuard.instance
    end

    def call(text)
      value = text.to_s
      return reject(:empty, nil) if value.strip.empty?

      tier = CharacterTiers::COMMON
      han_seen = false

      value.each_char do |char|
        if char.match?(HAN)
          han_seen = true
          level = @tiers.tier(char)
          return reject(:unlisted, char) if level.nil?

          tier = level if level > tier
        elsif char.match?(LATIN) || @punctuation.include?(char)
          next
        else
          return reject(:junk, char)
        end
      end

      return reject(:no_han, nil) unless han_seen

      marker = @mainland.offender(value)
      return reject(:mainland, marker) if marker

      Verdict.new(ok: true, tier: tier, reason: nil, offender: nil)
    end

    def ok?(text) = call(text).ok

    def tier_of(text) = call(text).tier

    private

    def reject(reason, offender)
      Verdict.new(ok: false, tier: nil, reason: reason, offender: offender)
    end
  end
end
