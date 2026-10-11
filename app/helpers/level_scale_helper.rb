# frozen_string_literal: true

module LevelScaleHelper
  HSK = {1 => "1", 2 => "2", 3 => "3", 4 => "4", 5 => "5", 6 => "6", 7 => "7–9"}.freeze
  COUNTS_KEY = "level_scale/items/v1"

  Step = Data.define(:grade, :band, :hsk, :items)

  def level_scale
    counts = level_item_counts
    total = 0
    HSK.map do |grade, hsk|
      total += counts.fetch(grade, 0)
      Step.new(grade:, band: placement_band(grade), hsk:, items: friendly_count(total))
    end
  end

  def level_scale_meta(step)
    [
      "TBCL #{step.grade}",
      t("onboarding.scale.hsk", level: step.hsk),
      t("onboarding.scale.items", count: step.items)
    ].join(" · ")
  end

  private

  def level_item_counts
    Rails.cache.fetch(COUNTS_KEY, expires_in: 1.day) do
      Lexeme.unrestricted.where(kind: %i[word character], level_index: HSK.keys).group(:level_index).count
    end
  end

  def friendly_count(count)
    step = if count < 1_000
      50
    else
      (count < 5_000) ? 100 : 500
    end

    [(count.to_f / step).round * step, step].max
  end
end
