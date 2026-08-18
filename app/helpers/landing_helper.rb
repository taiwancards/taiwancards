# frozen_string_literal: true

module LandingHelper
  GOLD_CARD_URL = "https://goldcard.nat.gov.tw/en"

  SCIENCE_POINTS = %w[corpus open linked].freeze

  def disclaimer_html
    t(
      "landing.disclaimer_html",
      gold_card: link_to(
        t("landing.gold_card"),
        GOLD_CARD_URL,
        rel: "noopener",
        target: "_blank",
        class: "underline underline-offset-2 hover:text-foreground"
      )
    )
  end

  WIDER = [
    [
      "taiwancards",
      "trainer",
      [:yes, "only"],
      [:yes, "with_pinyin"],
      [:yes, "seven_bands"],
      [:yes, "companion_service"],
      [:yes, "five"]
    ],
    ["hellochinese", "course", [:yes, nil], [:unknown, nil], [:no, "hsk"], [:unknown, nil], [:unknown, nil]],
    [
      "chineseskill",
      "course",
      [:unknown, nil],
      [:yes, "claimed"],
      [:no, "hsk"],
      [:unknown, "claimed"],
      [:unknown, nil]
    ],
    ["duchinese", "reader", [:yes, nil], [:yes, nil], [:no, "hsk"], [:no, nil], [:no, "one"]],
    ["superchinese", "course", [:unknown, nil], [:unknown, nil], [:no, "hsk"], [:unknown, nil], [:unknown, nil]],
    ["mondly", "course", [:unknown, "simplified_implied"], [:unknown, nil], [:no, "cefr"], [:no, nil], [:no, "one"]],
    ["heychina", "course", [:unknown, nil], [:unknown, nil], [:no, "hsk"], [:unknown, nil], [:unknown, nil]],
    ["immersive", "audio", [:yes, nil], [:unknown, nil], [:no, "no_exam"], [:no, nil], [:no, nil]],
    ["hanzii", "dictionary", [:unknown, nil], [:unknown, nil], [:yes, "ios_only"], [:unknown, nil], [:unknown, nil]],
    ["hanzidict", "dictionary", [:yes, nil], [:yes, nil], [:yes, "tw_textbooks"], [:unknown, nil], [:no, "no_srs"]],
    ["todaii", "reader", [:unknown, nil], [:unknown, nil], [:yes, "tagging"], [:no, nil], [:no, nil]],
    ["chineseguru", "trainer", [:yes, nil], [:unknown, nil], [:yes, nil], [:unknown, "training_only"], [:yes, "four"]],
    ["zhongchinese", "course", [:yes, "only"], [:yes, "with_pinyin"], [:yes, nil], [:no, nil], [:no, "one"]]
  ].freeze

  WIDER_NAMES = {
    "taiwancards" => "TaiwanCards",
    "hellochinese" => "HelloChinese",
    "chineseskill" => "ChineseSkill",
    "duchinese" => "Du Chinese",
    "superchinese" => "SuperChinese",
    "mondly" => "Mondly",
    "heychina" => "HeyChina",
    "immersive" => "Immersive Chinese",
    "hanzii" => "Hanzii",
    "hanzidict" => "Chinese Hanzi Dictionary",
    "todaii" => "Todaii Easy Chinese",
    "chineseguru" => "Chinese Guru",
    "zhongchinese" => "Zhong Chinese"
  }.freeze

  WIDER_COLUMNS = %w[traditional zhuyin tocfl tone facets].freeze

  PRODUCTS = {
    "taiwancards" => "TaiwanCards",
    "duolingo" => "Duolingo",
    "duocards" => "DuoCards",
    "anki" => "Anki",
    "skritter" => "Skritter",
    "pleco" => "Pleco"
  }.freeze

  COMPARISON = [
    [
      "target",
      [:yes, "all_of_it"],
      [:no, "simplified"],
      [:partial, "generic"],
      [:partial, "deck"],
      [:partial, "chinese_wide"],
      [:partial, "chinese_wide"]
    ],
    ["traditional", [:yes, "only"], [:no, nil], [:partial, "unclear"], [:partial, "deck"], [:yes, nil], [:yes, nil]],
    [
      "zhuyin",
      [:yes, "with_pinyin"],
      [:no, nil],
      [:no, nil],
      [:partial, "deck"],
      [:yes, "instead_of_pinyin"],
      [:yes, nil]
    ],
    [
      "tocfl",
      [:yes, "seven_bands"],
      [:no, "cefr"],
      [:no, nil],
      [:partial, "community_decks"],
      [:partial, "some_decks"],
      [:partial, "community_imports"]
    ],
    ["order", [:yes, "level_freq"], [:yes, "fixed_path"], [:no, nil], [:no, nil], [:no, nil], [:no, nil]],
    [
      "facets",
      [:yes, "five"],
      [:no, "one"],
      [:no, "one"],
      [:partial, "if_configured"],
      [:yes, "four"],
      [:partial, "configurable"]
    ],
    [
      "tone",
      [:yes, "companion_service"],
      [:no, "speech_no_tone"],
      [:no, nil],
      [:no, "addon_no_tone"],
      [:no, "drawn_not_spoken"],
      [:no, nil]
    ],
    [
      "handwriting",
      [:yes, nil],
      [:no, nil],
      [:no, nil],
      [:partial, "addons"],
      [:yes, "best_in_class"],
      [:partial, "lookup_only"]
    ],
    ["placement", [:yes, nil], [:yes, nil], [:no, nil], [:no, nil], [:no, nil], [:no, nil]],
    [
      "scheduler",
      [:yes, "fsrs6"],
      [:partial, "proprietary"],
      [:partial, "leitner"],
      [:yes, "fsrs_builtin"],
      [:partial, "proprietary"],
      [:partial, "not_published"]
    ],
    [
      "price",
      [:yes, "no_charge"],
      [:partial, "freemium"],
      [:partial, "free_tier"],
      [:yes, "free_paid_ios"],
      [:no, "per_year"],
      [:partial, "one_time"]
    ]
  ].freeze

  MARKS = {yes: "✓", partial: "±", no: "—", unknown: "?"}.freeze

  def comparison_mark(kind)
    MARKS.fetch(kind)
  end

  def comparison_mark_class(kind, own:)
    case kind
    when :yes
      own ? "text-brand" : "text-foreground"
    when :partial
      "text-muted-foreground"
    else
      "text-muted-foreground opacity-60"
    end
  end

  def comparison_own?(index)
    PRODUCTS.keys[index] == "taiwancards"
  end

  def wider_name(key)
    WIDER_NAMES.fetch(key)
  end
end
