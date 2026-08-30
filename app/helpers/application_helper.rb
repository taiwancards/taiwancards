# frozen_string_literal: true

module ApplicationHelper
  LAUNCH_YEAR = 2024

  PAGE_WIDTHS = {
    "narrow" => "max-w-3xl",
    "medium" => "max-w-5xl",
    "wide" => "max-w-[88rem]"
  }.freeze

  def wide_page = content_for(:page_width, "wide")

  def medium_page = content_for(:page_width, "medium")

  def page_width_class
    PAGE_WIDTHS.fetch(content_for(:page_width).to_s.strip, PAGE_WIDTHS.fetch("narrow"))
  end

  def subnav_width_class
    wide = PAGE_WIDTHS.fetch("wide")
    page_width_class == wide ? wide : PAGE_WIDTHS.fetch("medium")
  end

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
