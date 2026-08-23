# frozen_string_literal: true

require "json"

module Pronunciation
  module Acoustic
    module Templates
      module_function

      def stat(values)
        vals = values.compact.reject { |v| v.respond_to?(:nan?) && v.nan? }
        return nil if vals.empty?

        s = vals.sort
        {
          "median" => DTW::Statistics.median(s),
          "mad" => DTW::Statistics.median_absolute_deviation(s),
          "sd" => DTW::Statistics.standard_deviation(s),
          "p05" => percentile(s, 0.05),
          "p95" => percentile(s, 0.95),
          "min" => s.first,
          "max" => s.last,
          "n" => s.length
        }
      end

      def percentile(sorted, q)
        return sorted.first if sorted.length == 1

        x = q * (sorted.length - 1)
        lo = x.floor
        hi = [lo + 1, sorted.length - 1].min
        frac = x - lo
        (sorted[lo] * (1 - frac)) + (sorted[hi] * frac)
      end

      SPREAD_FLOOR = 0.15
      MIN_BAND = 6
      BAND_CORE = 0.10
      BAND_MAX_RANGE = 20.0
      BAND_FLOOR = 0.4

      def observed_band(curves, speakers = 1)
        usable = curves.compact.reject(&:empty?).select { |curve| sane_curve?(curve) }
        return {} if usable.length < MIN_BAND

        length = usable.first.length
        columns = Array.new(length) { |i| usable.map { |curve| curve[i] }.sort }
        low = columns.map { |c| percentile(c, BAND_CORE) }
        high = columns.map { |c| percentile(c, 1.0 - BAND_CORE) }
        {
          "spread" => columns.map { |c| [DTW::Statistics.median_absolute_deviation(c), SPREAD_FLOOR].max.round(3) },
          "low" => low.each_index.map { |i| widen(low[i], high[i], -1).round(3) },
          "high" => low.each_index.map { |i| widen(low[i], high[i], 1).round(3) },
          "n_band" => usable.length,
          "n_band_speakers" => speakers
        }
      end

      def sane_curve?(curve)
        (curve.max - curve.min) <= BAND_MAX_RANGE && curve.none? { |v| v.respond_to?(:nan?) && v.nan? }
      end

      def widen(low, high, side)
        middle = (low + high) / 2.0
        half = [(high - low) / 2.0, BAND_FLOOR].max
        middle + (side * half)
      end

      def curve_stat(curves)
        curves = curves.compact.reject(&:empty?)
        return nil if curves.empty?

        n = curves[0].length
        center = Array.new(n) { |i| DTW::Statistics.median(curves.map { |c| c[i] }) }
        sigma = Array.new(n) { |i| DTW::Statistics.median_absolute_deviation(curves.map { |c| c[i] }) }
        {"center" => center, "sigma" => sigma, "n" => curves.length}
      end

      def build(key, feature_rows, meta_rows, variability: nil, vot: :own)
        return nil if feature_rows.empty?

        syllable, tone = Syllables.parse_key(key)
        struct = Syllables.structure(syllable)

        kept, dropped = reject_outliers(feature_rows)
        rows = kept.empty? ? feature_rows : kept
        meta = rows.map { |r| meta_rows[feature_rows.index(r)] }.compact

        tone_seqs = rows.map { |r| r["tone_curve"] }
        tone_bary = DTW.barycenter(tone_seqs, length: Features::TONE_POINTS, iterations: 3)
        tone_curve = {
          "center" => tone_bary.center,
          "sigma" => tone_bary.dispersion.map { |v| [v, 0.4].max },
          "n" => tone_bary.count
        }.merge(observed_band(tone_seqs, meta.map { |m| m["speaker"] }.uniq.length))

        mfcc_seqs = rows.map { |r| r["mfcc"] }
        mfcc_bary = DTW.barycenter(mfcc_seqs, length: Features::MFCC_POINTS, iterations: 3)
        mfcc_curve = {
          "center" => mfcc_bary.center,
          "sigma" => mfcc_bary.dispersion.map { |frame| frame.map { |v| [v, 0.25].max } },
          "n" => mfcc_bary.count,
          "length" => mfcc_bary.length
        }

        vot_rows = rows.select { |r| r["vot_reliable"] }
        fmt_rows = rows.select { |r| Features.row_formants_reliable?(r) }
        fmt_rows = rows if fmt_rows.empty?

        tpl = {
          "key" => key,
          "syllable" => syllable,
          "tone" => tone,
          "pinyin" => key,
          "norm" => "standard",
          "structure" => {
            "initial" => struct[:initial],
            "initial_ipa" => struct[:initial_ipa],
            "medial" => struct[:medial],
            "nucleus" => struct[:nucleus],
            "apical" => struct[:apical]&.to_s,
            "final" => struct[:final],
            "coda" => struct[:coda],
            "nasal_coda" => struct[:nasal_coda],
            "aspirated" => struct[:aspirated],
            "sibilant" => struct[:sibilant]&.to_s
          },
          "provenance" => {
            "n_tokens" => rows.length,
            "n_formant_tokens" => fmt_rows.length,
            "n_dropped_outliers" => dropped,
            "n_speakers" => meta.map { |m| m["speaker"] }.uniq.length,
            "speakers" => meta.map { |m| m["speaker"] }.uniq.sort,
            "sources" => meta.group_by { |m| m["source"] }.transform_values(&:length),
            "n_isolated" => meta.count { |m| m["n_syllables"] == 1 },
            "confidence" => confidence_label(rows.length, meta.map { |m| m["speaker"] }.uniq.length)
          },
          "tone_contour" => tone_curve,
          "tone_range" => stat(rows.map { |r| r["tone_range"] }),
          "tone_slope" => stat(rows.map { |r| r["tone_slope"] }),
          "f0_register" => stat(rows.map { |r| r["f0_register"] }),
          "duration_ms" => stat(rows.map { |r| r["duration_ms"] }),
          "voiced_ms" => stat(rows.map { |r| r["voiced_ms"] }),
          "voiced_ratio" => stat(rows.map { |r| r["voiced_ratio"] }),
          "mfcc" => mfcc_curve,
          "f1" => curve_stat(fmt_rows.map { |r| r["f1"] }),
          "f2" => curve_stat(fmt_rows.map { |r| r["f2"] }),
          "f3" => curve_stat(fmt_rows.map { |r| r["f3"] }),
          "f1_mid" => stat(fmt_rows.map { |r| r["f1_mid"] || Features.mid_of(r["f1"]) }),
          "f2_mid" => stat(fmt_rows.map { |r| r["f2_mid"] || Features.mid_of(r["f2"]) }),
          "f3_mid" => stat(fmt_rows.map { |r| r["f3_mid"] || Features.mid_of(r["f3"]) }),
          "f1_ratio" => stat(fmt_rows.map { |r| r["f1_ratio"] }),
          "f2_ratio" => stat(fmt_rows.map { |r| r["f2_ratio"] }),
          "f1_over_f0" => stat(fmt_rows.map { |r| r["f1_over_f0"] }),
          "f2_over_f1" => stat(fmt_rows.map { |r| r["f2_over_f1"] }),
          "f2_onset_ratio" => stat(fmt_rows.map { |r| r["f2_onset_ratio"] }),
          "f1_onset_over_f0" => stat(fmt_rows.map { |r| r["f1_onset_over_f0"] }),
          "f2_end_over_f1" => stat(fmt_rows.map { |r| r["f2_end_over_f1"] }),
          "energy_tail_ratio" => stat(rows.map { |r| r["energy_tail_ratio"] }),
          "nasal_ratio_mid" => stat(rows.map { |r| r["nasal_ratio_mid"] }),
          "f2_end_ratio" => stat(fmt_rows.map { |r| r["f2_end_ratio"] }),
          "f2_delta_ratio" => stat(fmt_rows.map { |r| r["f2_delta_ratio"] }),
          "centroid_ratio" => stat(rows.map { |r| r["centroid_ratio"] }),
          "vot_ms" => vot == :own ? stat(vot_rows.map { |r| r["vot_ms"] }) : vot,
          "vot_ratio" => stat(vot_rows.map { |r| r["vot_ratio"] }),
          "fric_ms" => stat(rows.map { |r| r["fric_ms"] }),
          "fric_centroid" => stat(rows.map { |r| r["fric_centroid"] }),
          "fric_spread" => stat(rows.map { |r| r["fric_spread"] }),
          "fric_skewness" => stat(rows.map { |r| r["fric_skewness"] }),
          "fric_kurtosis" => stat(rows.map { |r| r["fric_kurtosis"] }),
          "nasal_ratio_tail" => stat(rows.map { |r| r["nasal_ratio_tail"] }),
          "nasal_antiformant" => stat(rows.map { |r| r["nasal_antiformant"] })
        }

        apply_variability!(tpl, variability) if variability
        tpl
      end

      def apply_variability!(tpl, v)
        Variability::FIELDS.each_key do |field|
          node = tpl[field]
          between = v[field]
          next unless node.is_a?(Hash) && node["mad"] && between

          within = [node["mad"].to_f, node["sd"].to_f * 0.8].max
          node["sigma_within"] = within.round(4)
          node["sigma_between"] = between.round(4)
          node["sigma"] = Variability.combine(within, between).round(4)
        end

        if (tc = tpl["tone_contour"]) && (bt = v["tone_contour"])
          tc["sigma_within"] = tc["sigma"].map { |x| x.round(3) }
          tc["sigma"] = tc["sigma"].each_with_index.map do |x, i|
            Variability.combine(x, bt[i] || bt.last).round(3)
          end
          if tc["spread"]
            tc["spread"] = tc["spread"].each_with_index.map do |x, i|
              Variability.combine(x, bt[i] || bt.last).round(3)
            end
            reach = band_reach(tc["n_band_speakers"])
            tc["low"] = tc["low"].each_with_index.map { |x, i| (x - (reach * (bt[i] || bt.last))).round(3) }
            tc["high"] = tc["high"].each_with_index.map { |x, i| (x + (reach * (bt[i] || bt.last))).round(3) }
          end
        end

        tpl["mfcc_scale"] = v["mfcc_scale"] if v["mfcc_scale"]
        tpl["variability_applied"] = true
      end

      MAD_TO_PERCENTILE = 1.9
      BAND_REACH = {1 => 1.0, 2 => 0.6, 3 => 0.3}.freeze

      def band_reach(speakers)
        MAD_TO_PERCENTILE * BAND_REACH.fetch(speakers.to_i, 0.0)
      end

      def confidence_label(n_tokens, n_speakers)
        if n_tokens >= 12 && n_speakers >= 4
          "high"
        elsif n_tokens >= 6 && n_speakers >= 3
          "medium"
        elsif n_tokens >= 3
          "low"
        else
          "very_low"
        end
      end

      def reject_outliers(rows)
        return [rows, 0] if rows.length < 5

        curves = rows.map { |r| r["tone_curve"] }
        n = curves[0].length
        med = Array.new(n) { |i| DTW::Statistics.median(curves.map { |c| c[i] }) }
        dists = curves.map { |c| Math.sqrt(c.each_with_index.sum { |v, i| (v - med[i]) ** 2 } / n) }
        m = DTW::Statistics.median(dists)
        s = DTW::Statistics.median_absolute_deviation(dists)
        return [rows, 0] if s <= 1e-9

        kept = rows.each_with_index.reject { |_r, i| (dists[i] - m) / s > 3.5 }.map(&:first)
        [kept, rows.length - kept.length]
      end
    end
  end
end
