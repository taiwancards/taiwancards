# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Vowel
      MIN_HZ = 50.0
      TRUSTED_HZ = (170.0..310.0)

      FIELDS = %w[f1_over_f0 f1_onset_over_f0].freeze

      module_function

      def place(features, speaker_hz = nil)
        hz = usable(speaker_hz) || usable(features["f0_ref_hz"])
        return features if hz.nil?

        features["f1_over_f0"] = ratio(features["f1_vowel"] || features["f1_mid"], hz)
        features["f1_onset_over_f0"] = ratio(features["f1_onset"], hz)
        features["pitch_referenced"] = TRUSTED_HZ.cover?(hz)
        features
      end

      def speaker_hz(rows)
        pitches = rows.filter_map { |row| usable(row["f0_ref_hz"]) }
        pitches.empty? ? nil : DTW::Statistics.median(pitches)
      end

      def usable(hz)
        value = hz.to_f
        value > MIN_HZ ? value : nil
      end

      def ratio(value, hz)
        return nil if value.nil? || value <= 0.0

        value / hz
      end
    end
  end
end
