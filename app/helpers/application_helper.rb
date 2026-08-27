# frozen_string_literal: true

module ApplicationHelper
  LAUNCH_YEAR = 2024

  def launch_year_range
    current = Time.current.year
    current <= LAUNCH_YEAR ? LAUNCH_YEAR.to_s : "#{LAUNCH_YEAR}–#{current}"
  end

  def input_classes
    "w-full rounded-md border border-input bg-background px-3 py-2 text-sm shadow-xs outline-none focus:ring-2 focus:ring-ring"
  end

  def locale_options
    I18n.available_locales.map { |code| [t("locales.#{code}", locale: code), code.to_s] }
  end

  # Shown only where the official lists say nothing, and never linked to a level page: the entry is
  # not on that list, it is only written with pieces a learner at this level already has.
  def approximate_level_badge(lexeme, scale)
    return if lexeme.data["#{scale}_grade"].present? || lexeme.data["#{scale}_level"].present?

    label = approximate_level_label(lexeme.data[scale], scale)
    return if label.nil?

    tag.span(
      t("#{scale}.approximate", n: label),
      class: "rounded-full bg-muted px-2.5 py-1 font-medium text-muted-foreground",
      title: t("#{scale}.approximate_hint", n: label)
    )
  end

  def approximate_level_label(index, scale)
    return if index.blank?

    return index.to_s if scale == "tbcl"

    SentenceProfile::TOCFL_LEVELS[index.to_i - 1]
  end

  def score_badge(lexeme)
    return if lexeme.score.nil?

    value = lexeme.score.round.clamp(1, 999)
    hue = (120 * (1 - (value / 999.0))).round
    tag.span(
      value,
      class: "inline-flex items-center rounded-full border-2 px-2 py-0.5 text-xs font-semibold tabular-nums",
      style: "border-color: hsl(#{hue} 75% 45%); color: hsl(#{hue} 80% 38%)",
      title: t("words.score_hint")
    )
  end
end
