# frozen_string_literal: true

module KanjiHelper
  INITIAL_GROUPS = {
    "bp" => %w[ㄅㄆ b\ p],
    "m" => %w[ㄇ m],
    "f" => %w[ㄈ f],
    "dt" => %w[ㄉㄊ d\ t],
    "n" => %w[ㄋ n],
    "l" => %w[ㄌ l],
    "gkh" => %w[ㄍㄎㄏ g\ k\ h],
    "jqx" => %w[ㄐㄑㄒ j\ q\ x],
    "zhchsh" => %w[ㄓㄔㄕ zh\ ch\ sh],
    "r" => %w[ㄖ r],
    "zcs" => %w[ㄗㄘㄙ z\ c\ s]
  }.freeze
  CODAS = {"n" => %w[ㄢㄣ -n], "ng" => %w[ㄤㄥ -ng], "open" => [nil, nil], "er" => %w[ㄦ er]}.freeze
  SUBROWS = {"ジ…" => "subrow_ji", "ニ…" => "subrow_ni"}.freeze
  WORD_BADGES = {
    "same" => "bg-emerald-500/10 text-emerald-700",
    "shift" => "bg-amber-500/10 text-amber-700",
    "new" => "bg-primary/10 text-primary"
  }.freeze
  TOP_GROUPS = 2
  SHOWN_SHARE = 0.05

  def taiwan_glyph(text, css: nil) = tag.span(text, lang: "zh-TW", class: css)

  def japan_glyph(text, css: nil) = tag.span(text, lang: "ja", class: css)

  def kanji_pair(from, to, css: nil)
    tag.span(class: class_names("inline-flex items-baseline gap-0.5", css)) do
      safe_join(
        [
          taiwan_glyph(from),
          tag.span("／", class: "text-muted-foreground"),
          japan_glyph(to, css: "text-muted-foreground")
        ]
      )
    end
  end

  def kanji_pattern_label(pattern)
    from = taiwan_glyph(pattern.from, css: "font-semibold")
    return t("kanji_bridge.pattern.part_html", from:) if pattern.to.blank?

    t("kanji_bridge.pattern.named_html", from:, to: japan_glyph(pattern.to, css: "font-semibold"))
  end

  def kanji_percent(share) = number_to_percentage(share.to_f * 100, precision: 1, strip_insignificant_zeros: true)

  def kanji_share(part, total) = total.to_i.zero? ? 0.0 : part.to_f / total

  def kanji_rule_label(share)
    rule = Huayu::KanjiBridge.reliable?(share)
    tag.span(
      t(rule ? "kanji_bridge.readings.rule" : "kanji_bridge.readings.tendency"),
      class: class_names(
        "rounded-full px-2 py-0.5 text-xs font-medium",
        rule ? "bg-emerald-500/10 text-emerald-700" : "bg-muted text-muted-foreground"
      )
    )
  end

  def kanji_group_label(group)
    return t("kanji_bridge.readings.zero") if group == "zero"

    zhuyin, pinyin = INITIAL_GROUPS.fetch(group, [group, nil])
    safe_join(
      [
        tag.span(zhuyin, lang: "zh-TW", class: "zhuyin zhuyin-locked"),
        (tag.span(pinyin, class: "pinyin pinyin-locked ml-1 text-muted-foreground") if pinyin)
      ].compact
    )
  end

  def kanji_coda_label(coda)
    zhuyin, latin = CODAS.fetch(coda, [nil, nil])
    return t("kanji_bridge.readings.open") if zhuyin.nil?

    safe_join(
      [
        tag.span(latin, class: "pinyin pinyin-locked"),
        tag.span(zhuyin, lang: "zh-TW", class: "zhuyin zhuyin-locked ml-1 text-muted-foreground")
      ]
    )
  end

  def kanji_row_label(row)
    return t("kanji_bridge.readings.#{SUBROWS[row]}") if SUBROWS.key?(row)

    t("kanji_bridge.readings.row", row:)
  end

  def kanji_initial_shares(row)
    total = row["total"].to_i
    row["groups"].to_h.filter_map do |group, count|
      share = kanji_share(count, total)
      [group, share] if share >= SHOWN_SHARE
    end
  end

  def kanji_top_share(row)
    kanji_share(row["groups"].to_h.values.first(TOP_GROUPS).sum, row["total"])
  end

  def kanji_example(item)
    tag.span(class: "inline-flex items-baseline gap-1.5") do
      safe_join(
        [
          link_to(
            item["char"],
            character_path(item["char"]),
            lang: "zh-TW",
            class: "text-base font-medium hover:text-primary"
          ),
          tag.span(item["on"], lang: "ja", class: "text-xs text-muted-foreground"),
          tag.span(item["zhuyin"], lang: "zh-TW", class: "zhuyin zhuyin-locked text-xs"),
          tag.span(item["pinyin"], class: "pinyin pinyin-locked text-xs text-muted-foreground")
        ]
      )
    end
  end

  def kanji_word_badge(word)
    tag.span(
      t("kanji_bridge.meanings.kinds.#{word.kind}"),
      lang: "ja",
      class: class_names("rounded-full px-2.5 py-1 text-xs font-medium", WORD_BADGES[word.kind])
    )
  end

  def kanji_level_tabs(section)
    [[t("kanji_bridge.levels.all"), kanji_path(section:), @level.nil?]] +
      Huayu::KanjiBridge::LEVELS.map { |level|
        [t("kanji_bridge.levels.level", level:), kanji_path(section:, level:), @level == level]
      }
  end
end
