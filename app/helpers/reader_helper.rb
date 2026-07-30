# frozen_string_literal: true

module ReaderHelper
  LEVEL_COLORS = {
    1 => "text-emerald-600 dark:text-emerald-400",
    2 => "text-teal-600 dark:text-teal-400",
    3 => "text-sky-600 dark:text-sky-400",
    4 => "text-indigo-600 dark:text-indigo-400",
    5 => "text-violet-600 dark:text-violet-400",
    6 => "text-amber-600 dark:text-amber-400",
    7 => "text-rose-600 dark:text-rose-400"
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
