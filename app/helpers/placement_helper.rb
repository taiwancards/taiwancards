# frozen_string_literal: true

module PlacementHelper
  TOCFL_BANDS = {1 => "Novice 1", 2 => "Novice 2", 3 => "A1", 4 => "A2", 5 => "B1", 6 => "B2", 7 => "C"}.freeze

  def placement_band(grade)
    TOCFL_BANDS[grade.to_i] || "—"
  end

  FRACTIONS = [nil, "\u2153", "\u00bd", "\u2154"].freeze

  def placement_result_label(test)
    base = t("placement.result_level", grade: test.result_grade, band: placement_band(test.result_grade))
    fraction = FRACTIONS[(test.position * FRACTIONS.length).floor.clamp(0, FRACTIONS.length - 1)]
    fraction ? "#{base} + #{fraction}" : base
  end

  def placement_grade_options
    (0..Placement::Ability::MAX_GRADE).map do |grade|
      label = grade.zero? ? t("placement.result_zero") : t(
        "placement.result_level",
        grade:,
        band: placement_band(grade)
      )
      [label, grade]
    end
  end

  def placement_choice_label(axis, choice)
    return t("tones.names.#{choice}", default: choice) if axis == "tones"

    choice
  end

  def level_label(value)
    case value
    when "zero"
      t("auth.levels.zero")
    when "phonetics"
      t("auth.levels.phonetics")
    else
      t("placement.result_level", grade: value, band: placement_band(value))
    end
  end
end
