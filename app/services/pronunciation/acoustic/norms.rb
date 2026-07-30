# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Norms
      STANDARD = "standard"
      TAIWAN = "taiwan"
      ALL = [STANDARD, TAIWAN].freeze

      TONE_TARGETS = {
        STANDARD => {
          1 => {
            curve: [0.3, 0.2, 0.1, 0.0, 0.0, -0.1, -0.2, -0.3],
            range: 1.5,
            note: "陰平 55: level high"
          },
          2 => {
            curve: [-3.2, -3.0, -2.4, -1.5, -0.3, 1.2, 2.6, 3.6],
            range: 7.0,
            note: "陽平 35: rising"
          },
          3 => {
            curve: [-1.0, -2.6, -3.6, -3.9, -3.5, -2.0, 0.6, 3.0],
            range: 7.0,
            note: "上聲 214: dip with a final rise"
          },
          4 => {
            curve: [4.6, 3.8, 2.4, 0.6, -1.4, -3.2, -4.4, -5.2],
            range: 9.5,
            note: "去聲 51: sharply falling"
          },
          5 => {
            curve: [0.6, 0.4, 0.2, 0.0, -0.2, -0.4, -0.7, -1.0],
            range: 2.0,
            note: "輕聲: short, unstressed"
          }
        },
        TAIWAN => {
          1 => {
            curve: [0.3, 0.2, 0.1, 0.0, 0.0, -0.1, -0.2, -0.3],
            range: 1.5,
            note: "44: level, register slightly below Beijing"
          },
          2 => {
            curve: [-2.8, -2.7, -2.3, -1.6, -0.6, 0.8, 2.2, 3.2],
            range: 6.2,
            note: "35/24: rise starts later and is shallower"
          },
          3 => {
            curve: [1.2, 0.0, -1.2, -2.2, -3.0, -3.6, -4.0, -4.2],
            range: 5.6,
            note: "21: low falling, NO final rise (the key difference)"
          },
          4 => {
            curve: [4.0, 3.4, 2.2, 0.8, -0.8, -2.2, -3.2, -3.8],
            range: 8.0,
            note: "53: falling, less deep than in Beijing"
          },
          5 => {
            curve: [0.5, 0.3, 0.2, 0.0, -0.2, -0.4, -0.6, -0.8],
            range: 2.0,
            note: "輕聲 is rarer in Taiwan; the full tone is often kept"
          }
        }
      }.freeze

      SEGMENTAL_DELTAS = {
        "zhi" => {
          "fric_centroid" => {
            shift: 700.0,
            sigma_scale: 2.2,
            note: "deretroflexion: zh moves toward z, noise centroid higher"
          },
          "fric_skewness" => {
            shift: 0.0,
            sigma_scale: 1.8,
            note: "noise shape varies more"
          },
          "f3" => {
            shift: 150.0,
            sigma_scale: 1.6,
            note: "retroflexion lowers F3 sharply; the drop is weaker in Taiwan"
          }
        },
        "zi" => {
          "fric_centroid" => {
            shift: 0.0,
            sigma_scale: 1.5,
            note: "the z/zh boundary is blurred in Taiwan"
          }
        },
        "ban" => {
          "nasal_ratio_tail" => {
            shift: 0.0,
            sigma_scale: 1.4,
            note: "-n vs -ng is less distinct in Taiwan"
          }
        },
        "bang" => {
          "nasal_ratio_tail" => {
            shift: 0.0,
            sigma_scale: 1.4,
            note: "-n vs -ng is less distinct in Taiwan"
          },
          "f2_mid" => {
            shift: 60.0,
            sigma_scale: 1.3,
            note: "the vowel before -ng is slightly less back"
          }
        },
        "pan" => {
          "nasal_ratio_tail" => {
            shift: 0.0,
            sigma_scale: 1.4,
            note: "-n vs -ng is less distinct in Taiwan"
          }
        },
        "pang" => {
          "nasal_ratio_tail" => {
            shift: 0.0,
            sigma_scale: 1.4,
            note: "-n vs -ng is less distinct in Taiwan"
          },
          "f2_mid" => {
            shift: 60.0,
            sigma_scale: 1.3,
            note: "the vowel before -ng is slightly less back"
          }
        }
      }.freeze

      module_function

      def to_taiwan(std)
        t = deep_dup(std)
        t["norm"] = TAIWAN
        applied = []

        tone = std["tone"]
        target = TONE_TARGETS[TAIWAN][tone]
        if target && t["tone_contour"]
          n = t["tone_contour"]["center"].length
          t["tone_contour"] = {
            "center" => resample(target[:curve], n),
            "sigma" => t["tone_contour"]["sigma"].map { |s| [s, 1.2].max },
            "n" => 0,
            "derived" => true
          }
          t["tone_range"] = (t["tone_range"] || {}).merge("median" => target[:range])
          applied << {"field" => "tone_contour", "note" => target[:note]}
        end

        (SEGMENTAL_DELTAS[std["syllable"]] || {}).each do |field, rule|
          node = t[field]
          next unless node

          if node.is_a?(Hash) && node.key?("median")
            node["median"] += rule[:shift] if rule[:shift]
            %w[mad sd].each { |k| node[k] *= rule[:sigma_scale] if node[k] && rule[:sigma_scale] }
          elsif node.is_a?(Hash) && node.key?("center")
            node["center"] = node["center"].map { |v| v + (rule[:shift] || 0.0) }
            node["sigma"] = node["sigma"].map { |v| v * (rule[:sigma_scale] || 1.0) }
          end

          applied << {"field" => field, "note" => rule[:note]}
        end

        t["provenance"] = (t["provenance"] || {}).merge(
          "measured" => false,
          "derived_from" => "standard",
          "method" => "rule-based deltas (see this file), NOT measurements from a Taiwan corpus",
          "applied_rules" => applied
        )
        t
      end

      def resample(curve, n)
        return Array.new(n, 0.0) if curve.empty?

        Array.new(n) do |i|
          x = i.to_f * (curve.length - 1) / (n - 1)
          lo = x.floor
          hi = [lo + 1, curve.length - 1].min
          f = x - lo
          (curve[lo] * (1 - f)) + (curve[hi] * f)
        end
      end

      def deep_dup(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
        when Array
          obj.map { |v| deep_dup(v) }
        else
          obj
        end
      end
    end
  end
end
