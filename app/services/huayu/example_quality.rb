# frozen_string_literal: true

module Huayu
  class ExampleQuality
    SCALE = 1000
    MIN_HAN = 5
    MAX_HAN = 40
    PEAK_LOW = 8
    PEAK_HIGH = 18
    COMMON_PER_MILLION = 5.0
    TAIWAN_CAP = 4.0

    WEIGHTS = {
      common: 0.25,
      length: 0.18,
      audio: 0.12,
      easy: 0.10,
      whole: 0.10,
      opening: 0.09,
      solo: 0.09,
      taiwan: 0.07
    }.freeze

    HAN = /\p{Han}/
    TERMINAL = /[。！？…][」』）】"']*\z/
    OPENERS = Set[
      "這",
      "那",
      "它",
      "他",
      "她",
      "其",
      "此",
      "該",
      "這些",
      "那些",
      "這樣",
      "那樣",
      "這裡",
      "那裡",
      "前者",
      "後者",
      "但",
      "但是",
      "而",
      "而且",
      "所以",
      "因此",
      "然後",
      "另外",
      "不過",
      "於是",
      "因為",
      "可是",
      "還有",
      "其中",
      "此外",
      "例如"
    ]
      .freeze

    SOLO = WEIGHTS.keys.index(:solo)

    Context = Data.define(:text, :tally, :terms)

    extend MemoizedInstance

    class << self
      def call(...) = instance.call(...)
    end

    def initialize(frequency: WordFrequency)
      @frequency = frequency
    end

    def call(text:, segments:, target:, difficulty: 0, taiwan: 0, audio: false)
      context = context(text:, segments:, difficulty:, taiwan:, audio:)
      return 0 if context.nil?

      score(context, target)
    end

    def context(text:, segments:, difficulty: 0, taiwan: 0, audio: false)
      han = text.scan(HAN).length
      return nil if han < MIN_HAN || han > MAX_HAN

      units = Array(segments)
      Context.new(text:, tally: units.tally, terms: terms(units:, han:, text:, difficulty:, taiwan:, audio:))
    end

    def score(context, target)
      hits = occurrences(context, target)
      return 0 if hits.zero?

      terms = context.terms.dup
      terms[SOLO] = WEIGHTS.fetch(:solo) * solo_fit(hits)
      (terms.sum * SCALE).round.clamp(0, SCALE)
    end

    private

    def terms(units:, han:, text:, difficulty:, taiwan:, audio:)
      fixed = {
        common: common_share(units),
        length: length_fit(han),
        audio: audio ? 1.0 : 0.0,
        easy: 1.0 - (difficulty.to_i.clamp(0, SCALE) / SCALE.to_f),
        whole: text.match?(TERMINAL) ? 1.0 : 0.0,
        opening: OPENERS.include?(units.first) ? 0.0 : 1.0,
        solo: 0.0,
        taiwan: [taiwan.to_i / TAIWAN_CAP, 1.0].min
      }

      WEIGHTS.map { |name, weight| weight * fixed.fetch(name) }
    end

    def occurrences(context, target)
      hits = context.tally[target]
      return hits if hits

      context.text.scan(target).length
    end

    def solo_fit(hits)
      case hits
      when 1
        1.0
      when 2
        0.5
      else
        0.2
      end
    end

    def length_fit(han)
      return 1.0 if han.between?(PEAK_LOW, PEAK_HIGH)
      return (han - MIN_HAN).fdiv(PEAK_LOW - MIN_HAN) if han < PEAK_LOW

      (MAX_HAN - han).fdiv(MAX_HAN - PEAK_HIGH)
    end

    def common_share(units)
      return 0.0 if units.empty?

      known = units.count { |unit| @frequency.adjusted(unit) >= COMMON_PER_MILLION }
      known.fdiv(units.length)
    end
  end
end
