# frozen_string_literal: true

module EverydayHelper
  SCALE_DOMAIN = "drinks"

  GLYPHS = {
    "food" => "食",
    "drinks" => "飲",
    "breakfast" => "早",
    "produce" => "菜",
    "life" => "家",
    "health" => "醫",
    "money" => "錢",
    "payments" => "付",
    "housing" => "屋",
    "admin" => "證",
    "work" => "工",
    "transport" => "車",
    "places" => "島",
    "nature" => "山",
    "travel" => "旅",
    "people" => "人",
    "slang" => "話",
    "civics" => "民",
    "leisure" => "樂",
    "faith" => "廟"
  }.freeze

  GROUPS = {
    "daily" => %w[food drinks breakfast produce life],
    "errands" => %w[health money payments housing admin work],
    "moving" => %w[transport places nature travel leisure],
    "society" => %w[people slang civics faith]
  }.freeze

  def everyday_glyph(domain)
    GLYPHS.fetch(domain, "臺")
  end

  def everyday_tag_label(tag)
    return nil if tag.blank?

    t("everyday.tags.#{tag}", default: tag)
  end

  SUGAR = [
    ["全糖", "quántáng", "full", 100],
    ["不要太甜", "búyào tài tián", "nine", 90],
    ["少糖", "shǎotáng", "less", 70],
    ["半糖", "bàntáng", "half", 50],
    ["微糖", "wéitáng", "light", 30],
    ["一分糖", "yìfēntáng", "one", 10],
    ["無糖", "wútáng", "none", 0]
  ].freeze

  ICE = [
    ["正常冰", "zhèngchángbīng", "normal", 100, false],
    ["少冰", "shǎobīng", "less", 60, false],
    ["微冰", "wéibīng", "little", 30, false],
    ["去冰", "qù bīng", "none", 0, false],
    ["常溫", "chángwēn", "room", 25, true],
    ["溫", "wēn", "warm", 60, true],
    ["熱", "rè", "hot", 100, true]
  ].freeze

  def everyday_scales?(area)
    area == SCALE_DOMAIN
  end

  def everyday_scale_bar(fill, warm:)
    tone = warm ? "bg-amber-500" : "bg-brand"
    tag.span(class: "block h-2 w-full overflow-hidden rounded-full bg-muted") do
      tag.span(class: "block h-full rounded-full #{tone}", style: "width:#{fill}%")
    end
  end
end
