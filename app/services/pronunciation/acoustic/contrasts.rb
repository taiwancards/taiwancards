# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Contrasts
      FEATURES = %w[
        vot_ms
        vot_ratio
        fric_ms
        fric_centroid
        centroid_ratio
        f1_ratio
        f2_ratio
        f2_end_ratio
        f2_delta_ratio
        nasal_ratio_tail
        duration_ms
        voiced_ratio
        tone_range
        tone_slope
        f0_register
      ]
        .freeze

      MIN_DPRIME = 0.8

      module_function

      def sigma_of(stat)
        return stat["sigma"].to_f if stat["sigma"]

        [stat["mad"].to_f, stat["sd"].to_f * 0.8].max
      end

      def dprime(a, b)
        return nil unless a.is_a?(Hash) && b.is_a?(Hash) && a["median"] && b["median"]

        sa = sigma_of(a)
        sb = sigma_of(b)
        pooled = Math.sqrt(((sa * sa) + (sb * sb)) / 2.0)
        return nil if pooled < 1e-9

        (a["median"] - b["median"]).abs / pooled
      end

      def tone_dprime(a, b)
        ca = a.dig("tone_contour", "center")
        cb = b.dig("tone_contour", "center")
        return nil unless ca && cb

        sa = a.dig("tone_contour", "sigma")
        sb = b.dig("tone_contour", "sigma")
        acc = 0.0
        ca.each_index do |i|
          pooled = Math.sqrt((((sa[i] || 1.0) ** 2) + ((sb[i] || 1.0) ** 2)) / 2.0)
          acc += ((ca[i] - cb[i]) / [pooled, 0.4].max) ** 2
        end

        Math.sqrt(acc / ca.length)
      end

      def profile(target_tpl, other_tpl)
        out = {}
        FEATURES.each do |f|
          d = dprime(target_tpl[f], other_tpl[f])
          next if d.nil? || d < MIN_DPRIME

          out[f] = {
            "d" => d.round(3),
            "direction" => (target_tpl[f]["median"] >= other_tpl[f]["median"]) ? 1 : -1
          }
        end

        td = tone_dprime(target_tpl, other_tpl)
        out["tone_contour"] = {"d" => td.round(3), "direction" => 0} if td && td >= MIN_DPRIME
        out
      end

      def weighted_distance(feats, tpl, prof)
        return nil if prof.empty?

        total = 0.0
        wsum = 0.0

        prof.each do |field, info|
          w = info["d"] ** 2

          if field == "tone_contour"
            tc = tpl["tone_contour"]
            next unless tc && feats["tone_curve"]

            acc = 0.0
            feats["tone_curve"].each_index do |i|
              s = [tc["sigma"][i] || 1.0, 0.4].max
              acc += ((feats["tone_curve"][i] - tc["center"][i]) / s) ** 2
            end

            z = Math.sqrt(acc / feats["tone_curve"].length)
          else
            st = tpl[field]
            val = feats[field]
            next unless st && val

            z = (val - st["median"]) / [sigma_of(st), 1e-6].max
          end

          total += w * (z ** 2)
          wsum += w
        end

        return nil if wsum <= 0

        Math.sqrt(total / wsum)
      end

      def merged_profile(target_key, templates)
        target = templates[target_key]
        return {} unless target

        syl, tone = Syllables.parse_key(target_key)
        merged = {}
        Syllables.confusion_set(syl, tone).each do |other|
          tpl = templates[other]
          next unless tpl

          profile(target, tpl).each do |f, info|
            merged[f] = info if merged[f].nil? || info["d"] > merged[f]["d"]
          end
        end

        merged
      end
    end
  end
end
