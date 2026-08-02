# frozen_string_literal: true

module ReaderHelper
  LEVEL_COLORS = {
    1 => "text-emerald-600",
    2 => "text-teal-600",
    3 => "text-sky-600",
    4 => "text-indigo-600",
    5 => "text-violet-600",
    6 => "text-amber-600",
    7 => "text-rose-600"
  }.freeze

  def reader_token_classes(token, known_ids)
    return "text-muted-foreground" if token.lexeme.nil?
    return "text-muted-foreground" if known_ids.include?(token.lexeme.id)

    [LEVEL_COLORS[reader_level(token.lexeme)] || "text-foreground", "underline decoration-dotted underline-offset-4"].join(
      " "
    )
  end

  def reader_level(lexeme)
    tocfl = lexeme.data["tocfl_level"]
    return PlacementHelper::TOCFL_BANDS.key(tocfl.to_s.sub("Novice", "Novice ")) if tocfl.present?

    lexeme.data["tbcl_grade"].presence&.to_i
  end

  def reader_reading(lexeme)
    return nil if lexeme.nil?

    lexeme.reading_set.first&.dig("zhuyin").presence || lexeme.reading_set.first&.dig("pinyin")
  end

  def reader_zhuyin(lexeme)
    lexeme&.reading_set&.first&.dig("zhuyin").presence
  end
end
