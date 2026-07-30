# frozen_string_literal: true

module Pronunciation
  class Verdict
    CELLS = %w[initial medial final tone syllable].freeze
    LEVELS = %w[green amber red dark].freeze

    FALLBACK = {
      "overall" => {"red" => 62, "green" => 87, "neg_median" => 67},
      "tone" => {"red" => 50, "green" => 91, "neg_median" => 37},
      "initial" => {"red" => 47, "green" => 92, "neg_median" => 47},
      "medial" => {"red" => 41, "green" => 100, "neg_median" => 70},
      "final" => {"red" => 55, "green" => 97, "neg_median" => 66},
      "syllable" => {"red" => 47, "green" => 88, "neg_median" => 67}
    }.freeze

    FALLBACK_REJECT = 78

    RED_FLOOR = 45
    MIN_RED = 20

    DARK_BAND = 0.4

    def initialize(store: TemplateStore.instance)
      @thresholds = store.thresholds["thresholds"] || {}
      @reject_below = store.thresholds.dig("thresholds", "reject_below") || FALLBACK_REJECT
      @bounds = {}
    end

    def level(cell, score)
      return "gray" if score.nil?

      b = bounds(cell)
      return "green" if score >= b["green"]
      return "amber" if score >= b["red"]
      return "red" if score > b["dark"]

      "dark"
    end

    alias_method :color, :level

    def bounds(cell)
      @bounds[cell] ||= begin
        raw = @thresholds[cell] || FALLBACK[cell] || FALLBACK["overall"]
        green = raw["green"].to_i
        neg = (raw["neg_median"] || FALLBACK.dig(cell, "neg_median") || 0).to_i
        red = raw["red"].to_i
        red = [neg, green - RED_FLOOR].max if red < MIN_RED
        dark = [neg, (red - (DARK_BAND * (green - red))).round].min.clamp(0, red - 1)

        {"green" => green, "red" => red, "dark" => dark}
      end
    end

    def rejected?(overall, best_match, expected)
      return false unless best_match

      best_match != expected && overall.to_i < bounds("overall")["red"]
    end

    def for_syllable(evaluation, expected: nil)
      parts = evaluation["parts"] || []
      overall = evaluation["overall"].to_i
      best = evaluation["best_match"]

      {
        "overall" => overall,
        "level" => level("overall", overall),
        "color" => level("overall", overall),
        "rejected" => rejected?(overall, best, expected || evaluation["expected"]),
        "fill" => overall.clamp(0, 100),
        "cells" => parts.to_h { |p| [p["id"], {"score" => p["score"], "color" => level(p["id"], p["score"])}] },
        "worst" => worst_part(parts),
        "best_match" => best
      }
    end

    def worst_part(parts)
      present = parts.reject { |p| p["score"].nil? }
      return nil if present.empty?

      present.min_by { |p|
        b = bounds(p["id"])
        band = [b["green"] - b["red"], 1].max
        (p["score"] - b["green"]).to_f / band
      }["id"]
    end
  end
end
