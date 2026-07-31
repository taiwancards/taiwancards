# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Variability
      FIELDS = {
        "vot_ms" => :absolute,
        "vot_ratio" => :relative,
        "fric_ms" => :absolute,
        "fric_centroid" => :absolute,
        "fric_spread" => :absolute,
        "fric_skewness" => :absolute,
        "nasal_antiformant" => :absolute,
        "centroid_ratio" => :relative,
        "f1_mid" => :absolute,
        "f2_mid" => :absolute,
        "f3_mid" => :absolute,
        "f1_ratio" => :relative,
        "f2_ratio" => :relative,
        "f2_end_ratio" => :relative,
        "nasal_ratio_tail" => :absolute,
        "duration_ms" => :absolute,
        "voiced_ms" => :absolute,
        "tone_range" => :absolute,
        "tone_slope" => :absolute,
        "f0_register" => :absolute
      }.freeze

      module_function

      def estimate(tokens_by_key, min_speakers: 3)
        out = {}

        FIELDS.each do |field, _kind|
          per_key = []
          tokens_by_key.each_value do |rows|
            by_spk = rows.group_by { |r| r["_speaker"] }
            medians = []
            within = []
            counts = []
            by_spk.each_value do |list|
              vals = list.filter_map { |r| r[field] }
              next if vals.empty?

              medians << Dsp.median(vals)
              counts << vals.length
              within << DTW::Statistics.median_absolute_deviation(vals) if vals.length >= 3
            end

            next if medians.length < min_speakers

            observed = DTW::Statistics.median_absolute_deviation(medians)
            n_mean = counts.sum.to_f / counts.length
            noise = within.empty? ? 0.0 : (Dsp.median(within) / Math.sqrt(n_mean))
            corrected = Math.sqrt([(observed ** 2) - (noise ** 2), 0.0].max)
            per_key << corrected
          end

          next if per_key.empty?

          out[field] = Dsp.median(per_key)
        end

        curves = []
        tokens_by_key.each_value do |rows|
          by_spk = rows.group_by { |r| r["_speaker"] }
          per_spk = by_spk.filter_map do |_spk, list|
            cs = list.filter_map { |r| r["tone_curve"] }
            next if cs.empty?

            n = cs[0].length
            Array.new(n) { |i| Dsp.median(cs.map { |c| c[i] }) }
          end

          next if per_spk.length < min_speakers

          n = per_spk[0].length
          curves << Array.new(n) { |i| DTW::Statistics.median_absolute_deviation(per_spk.map { |c| c[i] }) }
        end

        unless curves.empty?
          n = curves[0].length
          out["tone_contour"] = Array.new(n) { |i| Dsp.median(curves.map { |c| c[i] }) }
        end

        dists = []
        tokens_by_key.each_value do |rows|
          by_spk = rows.group_by { |r| r["_speaker"] }
          next if by_spk.size < 2

          reps = by_spk.filter_map do |_spk, list|
            m = list.filter_map { |r| r["mfcc"] }
            m.first
          end

          reps.combination(2).first(6).each { |(a, b)| dists << DTW.distance(a, b) }
        end

        out["mfcc_scale"] = dists.empty? ? nil : Dsp.median(dists)

        out
      end

      def combine(within, between)
        w = within.to_f
        b = between.to_f
        Math.sqrt((w * w) + (b * b))
      end
    end
  end
end
