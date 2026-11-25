# frozen_string_literal: true

module StandardContrastHelper
  STANDARD_CONTRAST_CLASS = "space-y-1"
  STANDARD_LINE_CLASS = {
    "taipei" => "leading-relaxed text-emerald-700",
    "beijing" => "text-[11px] leading-snug text-rose-700/70"
  }.freeze
  STANDARD_BADGE_CLASS = {
    "taipei" => "mr-1.5 inline-block rounded px-1.5 py-px align-baseline text-[10px] font-semibold uppercase tracking-wide bg-emerald-500/15 text-emerald-700",
    "beijing" => "mr-1.5 inline-block rounded px-1 py-px align-baseline text-[9px] font-medium uppercase tracking-wide bg-rose-500/10 text-rose-700/70"
  }.freeze
  STANDARD_LEGEND_CLASS = "flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground"
  STANDARD_LEGEND_ITEM_CLASS = {"taipei" => nil, "beijing" => "text-[11px] text-rose-700/70"}.freeze
  TAIWAN_TONE_POINTS = %w[range merge erhua].freeze

  def standard_contrast(section, key, css: "mt-2")
    entry = Huayu::StandardContrasts.for(section, key)
    return if entry.nil?

    lines = Huayu::StandardContrasts::SIDES.filter_map do |side|
      next if entry[side].blank?

      tag.p(
        safe_join([standard_badge(side), phon_markup(entry[side])]),
        class: STANDARD_LINE_CLASS.fetch(side),
        data: {standard: side}
      )
    end

    tag.div(safe_join(lines), class: [STANDARD_CONTRAST_CLASS, css], data: {standard_contrast: section})
  end

  def standard_badge(side) = tag.span(t("standards.#{side}"), class: STANDARD_BADGE_CLASS.fetch(side))

  def standard_legend(css: nil)
    items = Huayu::StandardContrasts::SIDES.map do |side|
      tag.span(
        safe_join([standard_badge(side), t("standards.#{side}_hint")]),
        class: STANDARD_LEGEND_ITEM_CLASS.fetch(side)
      )
    end

    tag.p(safe_join(items), class: [STANDARD_LEGEND_CLASS, css], data: {standard_legend: true})
  end

  def standard_words = render("tones/standard_words", words: Huayu::StandardContrasts.words)

  def taiwan_tone_points = TAIWAN_TONE_POINTS.filter_map { |slot| standard_contrast("tones", slot, css: nil) }
end
