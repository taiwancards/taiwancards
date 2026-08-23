# frozen_string_literal: true

require "json"

module Pronunciation
  module Acoustic
    class Analyzer
      REGISTER_CAP = 2.0
      REGISTER_WEIGHT = 1.5
      RANGE_WEIGHT = 0.5
      CONTOUR_SIGMA_FLOOR = 1.0
      MIN_TONE_VOICED_MS = 60.0
      CONTOUR_SIGMA_CAP = 1.0
      CONTOUR_SD_FLOOR = 1.0
      CONTOUR_TOLERANCE = 0.6
      CONTOUR_SPREAD_BLEND = 0.5
      CONTOUR_SPREAD_RANGE = (0.35..3.0)
      BAND_TOLERANCE = 0.8
      BAND_SCORING = true
      DIRECTION_GATE = 5.0

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
        "f1_over_f0" => 0.10,
        "f2_over_f1" => 0.20,
        "f2_onset_ratio" => 0.20,
        "f1_onset_over_f0" => 0.10,
        "f2_end_over_f1" => 0.20,
        "energy_tail_ratio" => 0.05,
        "nasal_ratio_tail" => 0.05,
        "nasal_antiformant" => 2.5,
        "nasal_ratio_mid" => 0.04,
        "duration_ms" => 45.0,
        "voiced_ms" => 45.0,
        "tone_range" => 1.6,
        "tone_slope" => 2.2,
        "f0_register" => 1.8
      }.freeze

      def initialize(store)
        @store = store
      end

      def template(key, norm) = @store.template(key, norm) || @store.template(key)

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
                "centroid" => f["fric_centroid"]&.round,
                "centroid_norm" => tpl["fric_centroid"]&.fetch("median", nil)&.round
              }
            )
        end

        if st["medial"] && !st["medial"].empty? && tpl["f2_over_f1"] && formants?(f)
          z = zscore(f["f2_over_f1"], tpl["f2_over_f1"], "f2_over_f1")
          medial_code = AxisNorms.typical?("medial", z) ? "medial.ok" : "medial.weak"
          axes << axis("medial", z, medial_code, {"medial" => st["medial"]})
        end

        height, front = vowel_pair(f)
        if tpl[height] && f[height] && formants?(f)
          zf1 = zscore(f[height], tpl[height], height)
          zf2 = tpl[front] && f[front] ? zscore(f[front], tpl[front], front) : 0.0
          zv = spread(f, tpl, vowel_fields(f))
          code, vars = vowel_code(zf1, zf2, st, zv)
          axes <<
            axis(
              "vowel",
              zv,
              code,
              vars,
              measured: {"f1" => f["f1_mid"]&.round, "f2" => f["f2_mid"]&.round}
            )
        end

        if st["nasal_coda"] && tpl["nasal_ratio_tail"]
          coda_tpl = muffled(tpl, f)
          zn = zscore(f["nasal_ratio_tail"], coda_tpl["nasal_ratio_tail"], "nasal_ratio_tail")
          axes <<
            axis(
              "coda",
              spread(f, coda_tpl, CODA_FIELDS),
              coda_code(zn),
              {"coda" => st["coda"]},
              measured: {
                "nasal_ratio" => f["nasal_ratio_tail"]&.round(2),
                "nasal_norm" => coda_tpl["nasal_ratio_tail"]["median"]&.round(2)
              }
            )
        end

        if tpl["mfcc"] && f["mfcc"]
          d = DTW.distance(f["mfcc"], tpl["mfcc"]["center"])
          z = d / mfcc_scale(tpl)
          axes << axis("timbre", z, AxisNorms.typical?("timbre", z) ? "timbre.ok" : "timbre.drift")
        end

        if tpl["voiced_ms"] && f["voiced_ms"]
          z = zscore(f["voiced_ms"], stretched(tpl["voiced_ms"], f), "voiced_ms")
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

      def formants?(f) = f.fetch("formants_reliable", true)

      def pitch_referenced?(f) = f.fetch("pitch_referenced", true)

      def vowel_fields(f) = pitch_referenced?(f) ? VOWEL_FIELDS : VOWEL_TRACT_FIELDS

      def vowel_pair(f) = pitch_referenced?(f) ? %w[f1_over_f0 f2_over_f1] : %w[f1_ratio f2_over_f1]

      def muffled(tpl, f)
        factor = ContextNorms.coda_factor(f["onset_after"])
        stat = tpl["nasal_ratio_tail"]
        return tpl if factor.nil? || factor <= 0.0 || stat.nil? || stat["median"].nil?

        tpl.merge("nasal_ratio_tail" => stat.merge("median" => stat["median"] * factor))
      end

      def stretched(stat, f)
        factor = ContextNorms.stretch(ContextNorms.spot_of(f["tone_before"], f["tone_after"]))
        return stat if factor.nil? || factor <= 0.0

        stat.merge("median" => stat["median"] * factor)
      end

      def band_of(tc, center)
        low = tc["low"]
        high = tc["high"]
        return nil if low.blank? || high.blank? || low.length != center.length

        middle = tc["center"]
        center.each_index.map do |i|
          shift = center[i] - middle[i]
          [(low[i] + shift).round(3), (high[i] + shift).round(3)]
        end
      end

      REGISTER_SHARE = {2 => 0.5, 3 => 0.75}.freeze

      def register_share(heard)
        return 1.0 if heard.nil?

        REGISTER_SHARE.fetch(heard.to_i, 1.0)
      end

      def gated(z, turned)
        return DIRECTION_GATE + z if turned

        DIRECTION_GATE * z / (DIRECTION_GATE + z)
      end

      def outside(value, edge)
        low, high = edge
        return low - value if value < low
        return value - high if value > high

        0.0
      end

      def relative_spread(sigma, length)
        values = Array.new(length) { |i| (sigma && sigma[i]).to_f }
        centre = values.sum / values.length
        return Array.new(length, 1.0) if centre <= 0.0

        values.map do |v|
          share = ((1.0 - CONTOUR_SPREAD_BLEND) + (CONTOUR_SPREAD_BLEND * (v / centre)))
          share.clamp(CONTOUR_SPREAD_RANGE.begin, CONTOUR_SPREAD_RANGE.end)
        end
      end

      def shape_of(curve, width = nil)
        centre = curve.sum / curve.length
        width ||= Math.sqrt(curve.sum { |v| (v - centre) ** 2 } / curve.length)
        width = CONTOUR_SD_FLOOR if width < CONTOUR_SD_FLOOR
        [curve.map { |v| (v - centre) / width }, width]
      end

      def spread(f, tpl, fields)
        zs = fields.filter_map do |field|
          next if tpl[field].nil? || f[field].nil?

          zscore(f[field], tpl[field], field)
        end

        return 0.0 if zs.empty?

        Math.sqrt(zs.sum { |v| v * v } / zs.length)
      end

      def tone_axis(f, tpl, _norm)
        tc = tpl["tone_contour"]
        return nil unless tc
        return nil if f["voiced_ms"] && f["voiced_ms"] < MIN_TONE_VOICED_MS

        user = f["tone_curve"]
        return nil if user.blank?

        center, sigma = reference_contour(tpl, tc)
        plain = center
        center = ContextNorms.place(center, tpl["tone"], f["tone_before"], f["tone_after"])

        band = band_of(tc, center)
        if BAND_SCORING && band
          tolerance = band.map { |low, high| ((high - low) / 2.0).round(2) }
          zs = user.each_index.map { |i| outside(user[i], band[i]) / BAND_TOLERANCE }
        else
          spoken, width = shape_of(user)
          wanted, = shape_of(center, shape_of(plain).last)
          spread = relative_spread(tc["spread"] || sigma, user.length)
          tolerance = spread.map { |v| (CONTOUR_TOLERANCE * v * width).round(2) }
          zs = spoken.each_index.map { |i| (spoken[i] - wanted[i]) / (CONTOUR_TOLERANCE * spread[i]) }
        end

        shape = Math.sqrt(zs.sum { |v| v * v } / zs.length)

        zr = tpl["tone_range"] ? zscore(f["tone_range"], tpl["tone_range"], "tone_range") : 0.0
        zsq = (shape ** 2) + (RANGE_WEIGHT * (zr ** 2))

        register = nil
        if f["f0_register"] && tpl["f0_register"]
          drift = fold_octave(f["f0_register"] - tpl["f0_register"]["median"])
          zreg = (drift / sigma_of(tpl["f0_register"], "f0_register")).clamp(-REGISTER_CAP, REGISTER_CAP)
          zsq += REGISTER_WEIGHT * register_share(f["n_register"]) * (zreg ** 2)
          register = {
            "actual" => f["f0_register"].round(1),
            "norm" => tpl["f0_register"]["median"].round(1),
            "z" => zreg.round(2)
          }
        end

        turned = wrong_direction(f, tpl)
        z = gated(Math.sqrt(zsq), turned)
        code, vars = tone_code(f, tpl, z, turned)
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
            "sigma" => tolerance.map { |v| v.round(2) },
            "band" => band&.map { |low, high| [low.round(2), high.round(2)] }
          }
        )
      end

      FLAT_SHARE = 0.65
      MIN_CONTOUR_TOKENS = 8
      DYNAMIC_TONES = [2, 3, 4].freeze

      def reference_contour(tpl, tc)
        target = canonical_target(tpl)
        return [tc["center"], tc["sigma"]] if target.nil?

        [Norms.resample(target[:curve], tc["center"].length), tc["sigma"].map { |v| [v, 1.2].max }]
      end

      def canonical_target(tpl)
        return nil unless DYNAMIC_TONES.include?(tpl["tone"])
        return nil if tpl.dig("tone_contour", "n").to_i >= MIN_CONTOUR_TOKENS

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

      CORE_REPORT = %w[duration_ms voiced_ms tone_range tone_slope f0_register].freeze
      INITIAL_REPORT = %w[vot_ms fric_ms].freeze
      SIBILANT_REPORT = %w[fric_centroid fric_spread centroid_ratio].freeze
      CODA_REPORT = %w[nasal_ratio_tail nasal_antiformant f2_end_ratio].freeze

      def relevant_fields(f, st)
        fields = vowel_pair(f) + CORE_REPORT
        fields += INITIAL_REPORT unless st["initial"].to_s.empty?
        fields += SIBILANT_REPORT if st["sibilant"]
        fields += CODA_REPORT if st["nasal_coda"]
        fields
      end

      def blind_fields(f, tpl)
        return [] if f["vot_reliable"]

        lead_in(f, tpl)&.fetch("code") == "lead_in.noisy" ? INITIAL_REPORT : %w[vot_ms]
      end

      LEAD_IN_MIN_MS = 120.0
      LEAD_IN_Z = 3.0

      def lead_in(f, tpl)
        return nil if f["vot_reliable"]

        ms = f["fric_ms"].to_f
        stat = tpl["fric_ms"]
        if stat && stat["median"] && ms >= LEAD_IN_MIN_MS && zscore(ms, stat, "fric_ms") >= LEAD_IN_Z
          return {"id" => "lead_in", "code" => "lead_in.noisy", "vars" => {"ms" => ms.round}}
        end

        return nil unless tpl["vot_ms"] && f["vot_ms"]

        {"id" => "lead_in", "code" => "lead_in.clipped", "vars" => {"initial" => tpl.dig("structure", "initial")}}
      end

      def report(f, tpl)
        blind = blind_fields(f, tpl)

        relevant_fields(f, tpl["structure"] || {}).filter_map do |field|
          stat = tpl[field]
          next if blind.include?(field) || stat.nil? || stat["median"].nil?

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

      SLOPE_DEAD_ZONE = 1.0
      SLOPE_REVERSAL = 1.2

      def tone_code(f, tpl, z, turned)
        expected = tpl["tone"]
        return ["tone.ok", {"tone" => expected}] if turned.nil? && AxisNorms.typical?("tone", z)

        vars = {
          "tone" => expected,
          "range" => f["tone_range"].round(1),
          "slope" => f["tone_slope"].round(1)
        }

        [turned || "tone.shape", vars]
      end

      def wrong_direction(f, tpl)
        reference = tpl.dig("tone_slope", "median")
        spoken = f["tone_slope"]
        return nil if reference.nil? || spoken.nil? || reference.abs < SLOPE_DEAD_ZONE
        return "tone.falls" if reference.positive? && spoken < -SLOPE_REVERSAL
        return "tone.rises" if reference.negative? && spoken > SLOPE_REVERSAL

        nil
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
        return ["vowel.apical", vars.merge("initial" => st["initial"])] if st["apical"]

        return [zf1.positive? ? "vowel.open" : "vowel.close", vars] if zf1.abs >= zf2.abs

        [zf2.positive? ? "vowel.front" : "vowel.back", vars]
      end

      def coda_code(zn)
        return "coda.ok" if AxisNorms.typical?("coda", zn.abs)

        zn.negative? ? "coda.weak" : "coda.heavy"
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
        "timbre" => "timbre",
        "duration" => nil
      }.freeze

      SIBILANT_FIELDS = %w[fric_spread fric_centroid centroid_ratio fric_skewness f2_onset_ratio].freeze
      VOWEL_FIELDS = %w[f1_over_f0 f2_over_f1 f2_onset_ratio f1_onset_over_f0].freeze
      VOWEL_TRACT_FIELDS = %w[f1_ratio f2_over_f1 f2_onset_ratio f2_ratio].freeze
      CODA_FIELDS = %w[nasal_ratio_tail nasal_ratio_mid energy_tail_ratio f2_end_over_f1].freeze

      AXIS_FEATURES = {
        "tone" => %w[tone_contour tone_range tone_slope f0_register],
        "initial" => %w[vot_ms vot_ratio fric_ms],
        "sibilant" => %w[fric_spread fric_centroid centroid_ratio fric_skewness],
        "vowel" => VOWEL_FIELDS,
        "coda" => CODA_FIELDS,
        "medial" => %w[f2_over_f1],
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

      PART_ORDER = %w[initial medial final tone timbre].freeze

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
          .map { |a| a.slice("id", "score", "code", "vars", "measured") }
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
