# frozen_string_literal: true

module CangjieHelper
  GROUP_TINTS = {
    "nature" => "bg-brand/10 text-brand",
    "strokes" => "bg-amber-500/10 text-amber-600",
    "body" => "bg-sky-500/10 text-sky-600",
    "shapes" => "bg-emerald-500/10 text-emerald-600",
    "special" => "bg-muted text-muted-foreground"
  }.freeze

  def cangjie_text(row) = Huayu::CangjieLessons.text(row, I18n.locale)
  def cangjie_group_tint(id) = GROUP_TINTS.fetch(id, GROUP_TINTS["special"])

  def cangjie_group_for(key)
    Huayu::CangjieLessons.groups.find { |group| group.keys.include?(key.to_s) }
  end

  def cangjie_code(code)
    tag.span(code.to_s.upcase, class: "font-mono uppercase tracking-widest")
  end

  def cangjie_glyph(glyph, rotate: nil)
    return tag.span("?", class: "text-muted-foreground") if glyph.blank?

    style = rotate ? "display:inline-block;transform:rotate(#{rotate}deg)" : nil
    tag.span(glyph, lang: "zh-TW", style: style)
  end

  def cangjie_block_heading(block, fallback = nil)
    text = cangjie_text(block["title"]) || fallback
    return if text.nil?

    tag.h2(text, class: "text-sm font-semibold uppercase tracking-wide text-muted-foreground")
  end

  DRILL_LABELS = %i[
    shape
    shape_question
    which
    which_question
    first
    first_question
    split
    split_question
    code
    code_question
    right
    wrong
    done
    best
  ]
    .freeze

  SPEED_LABELS = %i[wrong done again pace pace_unit rounds delta].freeze

  def cangjie_drill_labels = t("cangjie_lessons.drills").slice(*DRILL_LABELS)
  def cangjie_speed_labels = t("cangjie_lessons.speed").slice(*SPEED_LABELS)

  LEVEL_TINTS = {
    "Novice1" => "bg-emerald-500/15 text-emerald-700",
    "Novice2" => "bg-emerald-500/10 text-emerald-600",
    "A1" => "bg-sky-500/15 text-sky-700",
    "A2" => "bg-sky-500/10 text-sky-600",
    "B1" => "bg-amber-500/15 text-amber-700",
    "B2" => "bg-amber-500/10 text-amber-600",
    "C" => "bg-muted text-muted-foreground"
  }.freeze

  LEVEL_ORDER = %w[Novice1 Novice2 A1 A2 B1 B2 C].freeze

  def cangjie_level_tint(level) = LEVEL_TINTS.fetch(level, "bg-muted text-muted-foreground")
  def cangjie_level_label(level) = level.to_s.sub("Novice", "N")

  def cangjie_stage_label(stage) = Huayu::CangjieLessons.stage_name(stage, I18n.locale)
  def cangjie_lesson_badge(lesson)
    return lesson.letter if lesson.letter?

    lesson.id.to_s
  end
end
