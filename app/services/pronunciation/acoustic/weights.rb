# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Weights
      BASE = {
        "tone" => 3.0,
        "final" => 2.6,
        "initial" => 2.0,
        "medial" => 0.9
      }.freeze

      PART_FEATURES = {
        "tone" => %w[tone_contour tone_range tone_slope f0_register],
        "final" => %w[f1_ratio f2_ratio f2_end_ratio f2_delta_ratio nasal_ratio_tail],
        "initial" => %w[vot_ms vot_ratio fric_ms fric_centroid centroid_ratio],
        "medial" => %w[f2_ratio]
      }.freeze

      SATURATION = {"tone" => 2.0, "final" => 4.0, "initial" => 2.0, "medial" => 1.0}.freeze

      FLOOR = 0.45
      D_REF = 1.5

      @rivals = {}

      def self.reset!
        @rivals = {}
      end

      module_function

      def for_syllable(syllable, tone, present, profile: nil)
        counts = rivals(syllable, tone)

        present.to_h do |part|
          load = (counts[part].to_f / SATURATION[part]).clamp(0.0, 1.0)
          sep = separation(profile, part)
          [part, (BASE[part] * (FLOOR + ((1 - FLOOR) * [load, sep].max))).round(3)]
        end
      end

      def shares(weights)
        total = weights.values.sum
        return weights.transform_values { 0.0 } if total <= 0

        weights.transform_values { |w| (w / total).round(3) }
      end

      def separation(profile, part)
        return 0.0 if profile.blank?

        best = PART_FEATURES[part].filter_map { |f| profile[f]&.fetch("d", nil) }.max
        return 0.0 if best.nil?

        (best / D_REF).clamp(0.0, 1.0)
      end

      def rivals(syllable, tone)
        @rivals[[syllable, tone]] ||= count_rivals(syllable, tone)
      end

      def count_rivals(syllable, tone)
        all = Syllables.all_syllables
        me = Phonology.analyze(syllable)

        {
          "tone" => [Syllables.tones_for(syllable).length - 1, 0].max,
          "initial" => Phonology
            .neighbors(syllable, all)
            .count { |other| Phonology.analyze(other)[:initial] != me[:initial] },
          "medial" => all.count { |other|
            o = Phonology.analyze(other)
            o[:initial] == me[:initial] && rime(o) == rime(me) && o[:medial] != me[:medial]
          },
          "final" => all.count { |other|
            o = Phonology.analyze(other)
            o[:initial] == me[:initial] && o[:medial] == me[:medial] && rime(o) != rime(me)
          }
        }
      rescue StandardError
        {"tone" => tone ? 3 : 0, "initial" => 1, "medial" => 1, "final" => 4}
      end

      def rime(structure) = "#{structure[:nucleus]}#{structure[:coda]}"
    end
  end
end
