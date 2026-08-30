# frozen_string_literal: true

module LevelBadgesHelper
  SCHEMES = %w[tocfl tbcl].freeze
  MARK_LIMIT = 6

  Placement = Data.define(:value, :exact)

  def level_badges(lexeme, profile: nil, marks: false, compact: false)
    safe_join(SCHEMES.filter_map { |scheme| level_badge(lexeme, scheme, profile:, marks:, compact:) })
  end

  def level_badge(lexeme, scheme, profile: nil, marks: false, compact: false)
    placement = level_placement(lexeme, scheme, profile)
    return if placement.nil?

    name = level_name(scheme, placement.value)
    return if name.blank?

    return exact_level_badge(lexeme, scheme, placement.value, name, marks, compact) if placement.exact

    tag.span(
      t("#{scheme}.approximate", n: name),
      class: level_badge_classes(false, compact),
      title: approximate_level_hint(lexeme, scheme, name)
    )
  end

  def approximate_level_hint(lexeme, scheme, name)
    grade = lexeme.data["tocfl_via"] if scheme == "tocfl"
    return t("tocfl.approximate_hint_tbcl", n: name, grade:) if grade.present?

    t("#{scheme}.approximate_hint", n: name)
  end

  def frequency_badge(profile, compact: true)
    value = profile.level_for("freq")
    return if value.blank?

    label = "#{t("sentences.schemes.freq")} #{scheme_level_label("freq", value)}"
    return tag.span(label, class: level_badge_classes(true, compact)) if profile.exact_for?("freq")

    tag.span(
      "≈#{label}",
      class: level_badge_classes(false, compact),
      title: t("sentences.approximate_hint", count: profile.unknown_count)
    )
  end

  def level_badge_classes(exact, compact)
    size = compact ? "relative inline-flex min-h-6 items-center rounded px-1.5" : "inline-flex min-h-11 items-center rounded-full px-2.5 md:min-h-8"
    tint = exact ? "bg-primary/10 text-primary hover:bg-primary/20" : "bg-muted text-muted-foreground"

    "whitespace-nowrap font-medium #{size} #{tint}"
  end

  private

  def exact_level_badge(lexeme, scheme, value, name, marks, compact)
    label = t("#{scheme}.badge", n: name)
    classes = level_badge_classes(true, compact)
    path = level_list_path(scheme, value, marks ? level_marks(lexeme) : nil)
    return tag.span(label, class: classes) if path.nil?

    link_to(label, path, class: classes)
  end

  def level_placement(lexeme, scheme, profile)
    official = official_level(lexeme, scheme)
    return Placement.new(value: official, exact: true) if official.present?

    covered = profile&.level_for(scheme)
    return Placement.new(value: covered, exact: fully_covered?(lexeme, profile, scheme)) if covered.present?

    derived = lexeme.data[scheme]
    return if derived.blank?

    Placement.new(value: level_value(scheme, derived), exact: false)
  end

  def fully_covered?(lexeme, profile, scheme)
    lexeme.kind == "sentence" && profile.exact_for?(scheme)
  end

  def official_level(lexeme, scheme)
    scheme == "tbcl" ? lexeme.data["tbcl_grade"].to_s.presence : lexeme.data["tocfl_level"].presence
  end

  def level_value(scheme, index)
    scheme == "tbcl" ? index.to_s : SentenceProfile::TOCFL_LEVELS[index.to_i - 1]
  end

  def level_name(scheme, value)
    return value.to_s if scheme == "tbcl"

    novice = value.to_s.match(/\ANovice(\d)\z/)
    novice ? t("tocfl.novice", n: novice[1]) : value.to_s
  end

  def level_list_path(scheme, value, mark)
    options = mark.present? ? {mark:} : {}
    return tbcl_level_path(id: value, **options) if scheme == "tbcl"

    collection = tocfl_collection_ids[value]
    collection && tocfl_level_path(id: collection, **options)
  end

  def tocfl_collection_ids
    @tocfl_collection_ids ||= Collection.where(kind: :tocfl).pluck(:level_tag, :id).to_h
  end

  def level_marks(lexeme)
    units = lexeme.data["segments"]
    units = [lexeme.text] unless units.is_a?(Array) && units.length > 1

    units.uniq.first(MARK_LIMIT).join(",")
  end
end
