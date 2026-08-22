# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Register
      MIN_SYLLABLES = 2
      MIN_HZ = 50.0

      module_function

      def from_utterance(pitches, expected)
        usable = pitches.map(&:to_f).select { |hz| hz > MIN_HZ }
        return [] if usable.length < MIN_SYLLABLES

        centre = DTW::Statistics.median(usable)
        lift = average(expected)
        pitches.map { |hz| (hz.to_f > MIN_HZ) ? (12.0 * Math.log2(hz.to_f / centre)) + lift : nil }
      end

      def average(values)
        wanted = values.compact
        wanted.empty? ? 0.0 : wanted.sum / wanted.length
      end
    end
  end
end
