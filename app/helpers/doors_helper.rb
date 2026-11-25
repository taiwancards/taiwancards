# frozen_string_literal: true

module DoorsHelper
  WORDS_EXAMPLE = "你好、請問、姓、叫、臺灣、喜歡、喝、咖啡、茶、謝謝"
  TEXT_EXAMPLE = <<~TEXT
    週末我常常跟朋友去夜市。
    夜市裡有很多好吃的東西。
    我最喜歡喝珍珠奶茶。
  TEXT

  def door_cards
    [
      {key: "exam", glyph: :stats, path: exams_path, extra: [t("doors.exam.lists"), tocfl_levels_path]},
      {key: "words", glyph: :decks, path: words_door_path},
      {key: "text", glyph: :book, path: text_door_path}
    ]
  end

  def door_stash_attributes(door)
    {
      "data-controller": "door-stash",
      "data-door-stash-door-value": door,
      "data-door-stash-limit-value": DoorsController::TEXT_LIMIT,
      "data-door-stash-example-value": door == "words" ? WORDS_EXAMPLE : TEXT_EXAMPLE.strip,
      "data-door-stash-empty-value": t("doors.refused.empty"),
      "data-door-stash-no-hanzi-value": t("doors.refused.no_hanzi"),
      "data-door-stash-too-long-value": t(
        "doors.refused.too_long",
        limit: number_with_delimiter(DoorsController::TEXT_LIMIT)
      ),
      "data-door-stash-blocked-value": t("doors.refused.blocked")
    }
  end
end
