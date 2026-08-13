# frozen_string_literal: true

module Huayu
  class TextGate
    Verdict = Data.define(:ok, :tier, :reason, :offender) do
      def ok? = ok

      def rejected? = !ok
    end

    HAN = TWFilter::Han::CHAR

    REASONS = {
      empty: :empty,
      no_han: :no_han,
      junk_characters: :junk,
      unlisted: :unlisted,
      above_tier: :unlisted,
      simplified: :unlisted,
      converted_orthography: :unlisted,
      mainland: :china,
      mainland_soft: :china,
      cantonese: :china,
      regional: :china,
      foreign_topic: :china,
      erhua: :china,
      literary_density: :wenyan
    }.freeze

    POLICY = TWFilter::Policy.new(
      han_range: (1..Float::INFINITY),
      min_han_ratio: 0.0,
      max_tier: :rare,
      orthography_rejects: false,
      foreign_topics_reject: true,
      punctuation: :strict
    )

    extend MemoizedInstance

    class << self
      delegate :call, :ok?, :tier_of, to: :instance
    end

    def initialize
      @china = ChinaGuard.instance
    end

    def call(text)
      report = TWFilter.examine(text.to_s, policy: POLICY)
      finding = report.rejects.first
      return reject(finding) if finding

      stored = @china.offender(report.text)
      return Verdict.new(ok: false, tier: nil, reason: :china, offender: stored) if stored

      Verdict.new(ok: true, tier: report.tier || CharacterTiers::COMMON, reason: nil, offender: nil)
    end

    def ok?(text) = call(text).ok

    def tier_of(text) = call(text).tier

    private

    def reject(finding)
      Verdict.new(ok: false, tier: nil, reason: REASONS.fetch(finding.code, finding.code), offender: finding.detail)
    end
  end
end
