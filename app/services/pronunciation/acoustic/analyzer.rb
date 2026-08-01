# frozen_string_literal: true

require "json"

module Pronunciation
  module Acoustic
    class Analyzer
      REGISTER_CAP = 2.0
      CONTOUR_SIGMA_FLOOR = 1.0
      MIN_TONE_VOICED_MS = 60.0
      CONTOUR_SIGMA_CAP = 1.0

      SIGMA_FLOOR = {
        "vot_ms" => 8.0,
        "vot_ratio" => 0.03,
        "fric_ms" => 10.0,
        "fric_centroid" => 400.0,
        "fric_spread" => 300.0,
        "fric_skewness" => 0.5,
        "centroid_ratio" => 0.15,
        "f1_mid" => 90.0,
        "f2_mid" => 160.0,
        "f1_ratio" => 0.05,
        "f2_ratio" => 0.07,
        "nasal_ratio_tail" => 0.05,
        "nasal_antiformant" => 2.5,
        "nasal_ratio_mid" => 0.05,
        "duration_ms" => 45.0,
        "voiced_ms" => 45.0,
        "tone_range" => 1.6,
        "tone_slope" => 2.2,
        "f0_register" => 1.8
      }.freeze

      def initialize(store)
        @store = store
      end

      def template(key, norm) = @store.template(key, norm)

      def score_axes(f, tpl, norm)
        st = tpl["structure"]
        axes = []

        axes << tone_axis(f, tpl, norm)

        if tpl["vot_ms"] && f["vot_ms"] && f.fetch("vot_reliable", true)
          z = zscore(f["vot_ms"], tpl["vot_ms"], "vot_ms")
          code, vars = aspiration_code(z, st)
          axes <<
            axis(
              "initial",
              z,
              code,
              vars,
              measured: {
                "vot_ms" => f["vot_ms"].round,
                "vot_norm" => tpl["vot_ms"]["median"].round,
                "vot_sigma" => sigma_of(tpl["vot_ms"], "vot_ms").round
              }
            )
        end

        if st["sibilant"] && tpl["centroid_ratio"]
          zs = SIBILANT_FIELDS.filter_map do |field|
            next unless tpl[field] && f[field]

            zscore(f[field], tpl[field], field)
          end

          z = zs.empty? ? 0.0 : Math.sqrt(zs.sum { |v| v * v } / zs.length)
          z = -z if zscore(f["centroid_ratio"], tpl["centroid_ratio"], "centroid_ratio").negative?
          code, vars = sibilant_code(z, st, norm)
          axes <<
            axis(
              "sibilant",
              z,
              code,
              vars,
              measured: {
                "centroid" => f["fric_centroid"].round,
                "centroid_norm" => tpl["fric_centroid"]&.fetch("median", nil)&.round
              }
            )
        end

        if st["medial"] && !st["medial"].empty? && tpl["f2_ratio"]
          z = zscore(f["f2_ratio"], tpl["f2_ratio"], "f2_ratio")
          medial_code = AxisNorms.typical?("medial", z) ? "medial.ok" : "medial.weak"
          axes << axis("medial", z, medial_code, {"medial" => st["medial"]})
        end

        zf1 = tpl["f1_ratio"] ? zscore(f["f1_ratio"], tpl["f1_ratio"], "f1_ratio") : 0.0
        zf2 = tpl["f2_ratio"] ? zscore(f["f2_ratio"], tpl["f2_ratio"], "f2_ratio") : 0.0
        zv = Math.sqrt(((zf1 ** 2) + (zf2 ** 2)) / 2.0)
        code, vars = vowel_code(zf1, zf2, st, zv)
        axes <<
          axis(
            "vowel",
            zv,
            code,
            vars,
            measured: {"f1" => f["f1_mid"]&.round, "f2" => f["f2_mid"]&.round}
          )

        if st["nasal_coda"] && tpl["nasal_ratio_tail"]
          zn = zscore(f["nasal_ratio_tail"], tpl["nasal_ratio_tail"], "nasal_ratio_tail")
          za = if tpl["nasal_antiformant"] && f["nasal_antiformant"]
            zscore(f["nasal_antiformant"], tpl["nasal_antiformant"], "nasal_antiformant")
          end

          parts = [zn, zf2, za].compact
          zc = Math.sqrt(parts.sum { |v| v * v } / parts.length)
          code, vars = coda_code(zn, zf2, za, st, zc)
          axes << axis("coda", zc, code, vars)
        end

        if tpl["mfcc"]
          d = DTW.distance(f["mfcc"], tpl["mfcc"]["center"])
          z = d / mfcc_scale(tpl)
          axes << axis("timbre", z, AxisNorms.typical?("timbre", z) ? "timbre.ok" : "timbre.drift")
        end

        if tpl["voiced_ms"] && f["voiced_ms"]
          z = zscore(f["voiced_ms"], tpl["voiced_ms"], "voiced_ms")
          axes <<
            axis(
              "duration",
              z,
              duration_code(z, tpl["tone"]),
              {"tone" => tpl["tone"]},
              measured: {"voiced_ms" => f["voiced_ms"].round, "voiced_norm" => tpl["voiced_ms"]["median"].round}
            )
        end

        axes.compact
      end

      def tone_axis(f, tpl, _norm)
        tc = tpl["tone_contour"]
        return nil unless tc
        return nil if f["voiced_ms"] && f["voiced_ms"] < MIN_TONE_VOICED_MS

        user = f["tone_curve"]
        center, sigma = reference_contour(tpl, tc)

        zs = user.each_index.map do |i|
          s = (sigma[i] || CONTOUR_SIGMA_FLOOR).clamp(CONTOUR_SIGMA_FLOOR, CONTOUR_SIGMA_CAP)
          (user[i] - center[i]) / s
        end

        z = Math.sqrt(zs.sum { |v| v * v } / zs.length)

        zr = tpl["tone_range"] ? zscore(f["tone_range"], tpl["tone_range"], "tone_range") : 0.0
        z = Math.sqrt(((z ** 2) + (0.5 * (zr ** 2))) / 1.5)

        register = nil
        if f["f0_register"] && tpl["f0_register"]
          drift = fold_octave(f["f0_register"] - tpl["f0_register"]["median"])
          zreg = (drift / sigma_of(tpl["f0_register"], "f0_register")).clamp(-REGISTER_CAP, REGISTER_CAP)
          z = Math.sqrt(((z ** 2) + (0.5 * (zreg ** 2))) / 1.5)
          register = {
            "actual" => f["f0_register"].round(1),
            "norm" => tpl["f0_register"]["median"].round(1),
            "z" => zreg.round(2)
          }
        end

        code, vars = tone_code(f, tpl, z)
        axis(
          "tone",
          z,
          code,
          vars,
          measured: {
            "range" => f["tone_range"].round(1),
            "slope" => f["tone_slope"].round(1),
            "register" => register,
            "curve" => user.map { |v| v.round(2) },
            "reference" => center.map { |v| v.round(2) },
            "sigma" => sigma.map { |v| v.round(2) }
          }
        )
      end

      FLAT_SHARE = 0.65
      DYNAMIC_TONES = [2, 3, 4].freeze

      def reference_contour(tpl, tc)
        target = canonical_target(tpl)
        return [tc["center"], tc["sigma"]] if target.nil?

        [Norms.resample(target[:curve], tc["center"].length), tc["sigma"].map { |v| [v, 1.2].max }]
      end

      def canonical_target(tpl)
        return nil unless DYNAMIC_TONES.include?(tpl["tone"])

        target = Norms::TONE_TARGETS[Norms::TAIWAN][tpl["tone"]]
        measured = tpl.dig("tone_range", "median")
        return nil if target.nil? || measured.nil? || measured >= target[:range] * FLAT_SHARE

        target
      end

      def rank_candidates(f, expected_key, norm)
        syl, tone = Syllables.parse_key(expected_key)
        keys = ([expected_key] + Syllables.confusion_set(syl, tone)).uniq
        target = template(expected_key, norm)
        return [] unless target

        rows = keys.filter_map do |k|
          tpl = template(k, norm)
          next unless tpl

          dist = if k == expected_key
            prof = Contrasts.merged_profile(expected_key, candidate_templates(keys, norm))
            Contrasts.weighted_distance(f, tpl, prof)
          else
            prof = Contrasts.profile(target, tpl)
            Contrasts.weighted_distance(f, tpl, prof)
          end

          next unless dist

          {
            "key" => k,
            "distance" => dist.round(3),
            "pinyin" => tpl["pinyin"],
            "zhuyin" => tpl["zhuyin"],
            "n_features" => prof.size
          }
        end

        rows.sort_by! { |r| r["distance"] }

        if rows.length >= 2 && rows[0]["distance"] > 0
          margin = (rows[1]["distance"] - rows[0]["distance"]) / rows[0]["distance"]
          rows[0]["margin"] = margin.round(3)
          rows[0]["ambiguous"] = margin < 0.12
        end

        rows
      end

      def candidate_templates(keys, norm)
        keys.to_h { |k| [k, template(k, norm)] }.compact
      end

      CORE_REPORT = %w[f1_ratio f2_ratio duration_ms voiced_ms tone_range tone_slope f0_register].freeze
      INITIAL_REPORT = %w[vot_ms fric_ms].freeze
      SIBILANT_REPORT = %w[fric_centroid fric_spread centroid_ratio].freeze
      CODA_REPORT = %w[nasal_ratio_tail nasal_antiformant f2_end_ratio].freeze

      def relevant_fields(st)
        fields = CORE_REPORT.dup
        fields += INITIAL_REPORT unless st["initial"].to_s.empty?
        fields += SIBILANT_REPORT if st["sibilant"]
        fields += CODA_REPORT if st["nasal_coda"]
        fields
      end

      def report(f, tpl)
        relevant_fields(tpl["structure"] || {}).filter_map do |field|
          stat = tpl[field]
          next if stat.nil? || stat["median"].nil?

          value = f[field]
          {
            "field" => field,
            "value" => value&.round(2),
            "norm" => stat["median"].round(2),
            "sigma" => sigma_of(stat, field).round(2),
            "z" => value ? zscore(value, stat, field).round(2) : nil,
            "n" => stat["n"]
          }
        end
      end

      def deviations(f, tpl)
        SyllableSkill::TRACKED
          .filter_map { |field|
            next unless tpl[field] && f[field]

            [field, zscore(f[field], tpl[field], field).round(2)]
          }
          .to_h
      end

      OCTAVE = 12.0

      def fold_octave(semitones)
        folded = semitones.to_f % OCTAVE
        folded > (OCTAVE / 2) ? folded - OCTAVE : folded
      end

      def guess_tone(f, norm)
        targets = Norms::TONE_TARGETS[norm]
        scored = targets.map do |t, spec|
          target = Norms.resample(spec[:curve], f["tone_curve"].length)
          d = Math.sqrt(
            f["tone_curve"].each_index.sum { |i| (f["tone_curve"][i] - target[i]) ** 2 } /
              f["tone_curve"].length
          )
          d += 1.5 if t == 5 && f["duration_ms"] > 260
          d += 1.0 if t != 5 && f["duration_ms"] < 170
          {"tone" => t, "distance" => d, "note" => spec[:note]}
        end

        scored.sort_by { |r| r["distance"] }.first(3)
      end

      def tone_code(f, tpl, z)
        expected = tpl["tone"]
        return ["tone.ok", {"tone" => expected}] if AxisNorms.typical?("tone", z)

        got = guess_tone(f, tpl["norm"] || "standard").first["tone"]
        vars = {
          "tone" => expected,
          "got" => got,
          "range" => f["tone_range"].round(1),
          "slope" => f["tone_slope"].round(1)
        }

        return ["tone.wrong", vars] if got != expected

        ["tone.shape", vars]
      end

      def aspiration_code(z, st)
        initial = st["initial"]
        vars = {"initial" => initial, "ipa" => st["initial_ipa"]}
        return ["initial.ok", vars] if AxisNorms.typical?("initial", z)

        pair = Phonology::ASPIRATION_PAIRS[initial]
        vars["pair"] = pair
        return ["initial.under_aspirated", vars] if st["aspirated"] && z.negative?
        return ["initial.over_aspirated", vars] if !st["aspirated"] && z.positive?

        ["initial.vot_off", vars]
      end

      def sibilant_code(z, st, _norm)
        series = st["sibilant"]
        vars = {"initial" => st["initial"], "ipa" => st["initial_ipa"], "series" => series}
        return ["sibilant.ok", vars] if AxisNorms.typical?("sibilant", z)

        vars["counterparts"] = Phonology::SERIES_COUNTERPARTS[st["initial"]] || []
        ["sibilant.#{z.positive? ? "too_front" : "too_back"}", vars]
      end

      def vowel_code(zf1, zf2, st, zv)
        vars = {"final" => st["final"], "nucleus" => st["nucleus"]}
        return ["vowel.ok", vars] if AxisNorms.typical?("vowel", zv)

        return [zf1.positive? ? "vowel.open" : "vowel.close", vars] if zf1.abs >= zf2.abs

        [zf2.positive? ? "vowel.front" : "vowel.back", vars]
      end

      CODA_WEAK_Z = -1.5
      CODA_HEAVY_Z = 1.5
      CODA_PLACE_Z = 1.2

      def coda_code(zn, zf2, za, st, zc)
        vars = {"coda" => st["coda"]}
        return ["coda.ok", vars] if AxisNorms.typical?("coda", zc)
        return ["coda.weak", vars] if zn <= CODA_WEAK_Z && zn.abs > zf2.abs
        return ["coda.heavy", vars] if zn >= CODA_HEAVY_Z && right_place?(za, zf2)

        ["coda.#{st["coda"] == "n" ? "ng_for_n" : "n_for_ng"}", vars]
      end

      def right_place?(za, zf2)
        return false if za.nil?

        za.abs < CODA_PLACE_Z && zf2.abs < CODA_PLACE_Z
      end

      def duration_code(z, tone)
        return "duration.ok" if AxisNorms.typical?("duration", z)

        return tone == 5 ? "duration.neutral_long" : "duration.ok" if z.positive?

        "duration.short"
      end

      def mfcc_scale(tpl)
        s = tpl["mfcc_scale"].to_f
        return s if s > 0.5

        sig = DTW::Statistics.mean(tpl.dig("mfcc", "sigma").map { |v| DTW::Statistics.mean(v) })
        [sig * 2.4, 1.0].max
      end

      def sigma_of(stat, field)
        return [stat["sigma"].to_f, SIGMA_FLOOR[field] || 1.0].max if stat["sigma"]

        [stat["mad"].to_f, stat["sd"].to_f * 0.8, SIGMA_FLOOR[field] || 1.0].max
      end

      def zscore(value, stat, field)
        return 0.0 if value.nil? || stat.nil?

        (value - stat["median"]) / sigma_of(stat, field)
      end

      def score_from_z(z)
        (100.0 * Math.exp(-(z.abs ** 2) / 8.0)).round
      end

      AXIS_WEIGHT = {
        "tone" => 3.0,
        "initial" => 2.0,
        "sibilant" => 2.0,
        "vowel" => 2.0,
        "coda" => 2.0,
        "medial" => 1.0,
        "timbre" => 1.5,
        "duration" => 0.7
      }.freeze

      def axis(id, z, code, vars = {}, measured: {})
        {
          "id" => id,
          "part" => PART_OF[id],
          "z" => z.round(2),
          "score" => AxisNorms.score(id, z),
          "ok" => AxisNorms.typical?(id, z),
          "code" => code,
          "vars" => vars,
          "measured" => measured
        }
      end

      PART_OF = {
        "tone" => "tone",
        "initial" => "initial",
        "sibilant" => "initial",
        "medial" => "medial",
        "vowel" => "final",
        "coda" => "final",
        "timbre" => nil,
        "duration" => nil
      }.freeze

      SIBILANT_FIELDS = %w[fric_spread fric_centroid centroid_ratio fric_skewness].freeze

      AXIS_FEATURES = {
        "tone" => %w[tone_contour tone_range tone_slope f0_register],
        "initial" => %w[vot_ms vot_ratio fric_ms],
        "sibilant" => %w[fric_spread fric_centroid centroid_ratio fric_skewness],
        "vowel" => %w[f1_ratio f2_ratio],
        "coda" => %w[f2_end_ratio nasal_antiformant nasal_ratio_tail f2_delta_ratio],
        "medial" => %w[f2_ratio],
        "duration" => %w[duration_ms voiced_ratio],
        "timbre" => []
      }.freeze

      def overall_score(axes, profile = nil)
        return 0 if axes.empty?

        num = 0.0
        den = 0.0
        axes.each do |a|
          base = AXIS_WEIGHT[a["id"]] || 1.0
          w = if profile
            fields = AXIS_FEATURES[a["id"]] || []
            best = fields.filter_map { |f| profile[f]&.fetch("d", nil) }.max
            (0.25 * base) + (base * (best || 0.0))
          else
            base
          end

          num += w * a["score"]
          den += w
        end

        den.zero? ? 0 : (num / den).round
      end

      PART_ORDER = %w[initial medial final tone].freeze

      def part_scores(axes)
        by_part = axes.group_by { |a| a["part"] }

        PART_ORDER.filter_map do |part|
          members = by_part[part]
          next if members.blank?

          num = members.sum { |m| (AXIS_WEIGHT[m["id"]] || 1.0) * m["score"] }
          den = members.sum { |m| AXIS_WEIGHT[m["id"]] || 1.0 }
          worst = members.min_by { |m| m["score"] }

          {
            "id" => part,
            "score" => (num / den).round,
            "code" => worst["code"],
            "vars" => worst["vars"],
            "z" => worst["z"],
            "measured" => members.reduce({}) { |acc, m| acc.merge(m["measured"] || {}) }
          }
        end
      end

      def advisories(axes)
        axes
          .select { |a| a["part"].nil? }
          .map { |a| {"id" => a["id"], "score" => a["score"], "code" => a["code"], "measured" => a["measured"]} }
      end

      def weighted_overall(parts, weights)
        num = 0.0
        den = 0.0
        parts.each do |part|
          w = weights[part["id"]] || Weights::BASE[part["id"]] || 1.0
          num += w * part["score"]
          den += w
        end

        den.zero? ? 0 : (num / den).round
      end
    end
  end
end
