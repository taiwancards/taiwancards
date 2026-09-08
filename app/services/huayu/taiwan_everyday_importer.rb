# frozen_string_literal: true

module Huayu
  class TaiwanEverydayImporter < CuratedPageImporter
    PATH = AppData.path("huayu/taiwan_everyday.json")
    SOURCE = "Taiwan everyday"
    COLLECTION = "Taiwan everyday"
    COLLECTION_KIND = :everyday
    COLLECTION_POSITION = 900
    DOMAINS = %w[
      food
      drinks
      breakfast
      produce
      life
      slang
      people
      work
      transport
      money
      payments
      housing
      civics
      places
      nature
      travel
      admin
      health
      leisure
      faith
    ]
      .freeze

    private

    def accepted?(entry) = ORIGINS.include?(entry["origin"].to_s) && REGISTERS.include?(entry["register"].to_s)

    def import(entry, index)
      lexeme = @upserter.word(entry["text"], readings: readings(entry), meanings: meanings(entry), source: SOURCE)
      lexeme.data = lexeme.data.merge(metadata(entry))
      lexeme.save! if lexeme.changed?

      @upserter.link_characters(lexeme)
      link_forms(lexeme, entry)
      collection.add_lexeme(lexeme, position: index)
      lexeme
    end

    def link_forms(lexeme, entry)
      %w[abbr full].each do |kind|
        form = short_form(entry, kind)
        next if form.nil?
        next if form["text"] == lexeme.text

        variant = @upserter.word(
          form["text"],
          readings: {"pinyin" => form["pinyin"], "zhuyin" => form["zhuyin"]}.compact_blank,
          meanings: meanings(entry).compact_blank,
          source: SOURCE
        )
        counterpart = kind == "abbr" ? "full" : "abbr"
        variant.data = variant.data.merge("variant_of" => lexeme.text, counterpart => back_reference(lexeme))
        variant.save! if variant.changed?
        @upserter.link_characters(variant)
      end
    end

    def back_reference(lexeme)
      {
        "text" => lexeme.text,
        "pinyin" => lexeme.readings["pinyin"],
        "zhuyin" => lexeme.readings["zhuyin"]
      }.compact_blank
    end

    def placements(entry)
      primary = {"domain" => entry["domain"].presence || "life", "tag" => entry["tag"].presence}.compact
      extra = Array(entry["also"]).filter_map do |row|
        domain = row["domain"].presence
        next unless DOMAINS.include?(domain)

        {"domain" => domain, "tag" => row["tag"].presence}.compact
      end

      ([primary] + extra).uniq
    end

    def metadata(entry)
      {
        "taiwan_only" => entry.fetch("marked", true),
        "facets" => FACETS,
        "tier" => tier(entry),
        "rank" => entry["rank"].presence&.to_i,
        "origin" => entry["origin"],
        "register" => entry["register"],
        "domain" => entry["domain"].presence || "life",
        "china" => entry["china"].presence,
        "tag" => entry["tag"].presence,
        "placements" => placements(entry),
        "lines" => entry["lines"].presence,
        "lat" => entry["lat"],
        "lon" => entry["lon"],
        "hokkien" => hokkien(entry),
        "note" => note(entry),
        "examples" => examples(entry),
        "abbr" => short_form(entry, "abbr"),
        "full" => short_form(entry, "full"),
        "capital" => capital(entry)
      }.compact
    end

    def capital(entry)
      text = entry["capital"].presence
      return if text.nil?

      pinyin = entry["capital_pinyin"].presence
      {
        "text" => text,
        "pinyin" => pinyin,
        "zhuyin" => (Zhuyin.from_pinyin(pinyin) if pinyin),
        "meaning" => {"en" => entry["capital_en"], "ru" => entry["capital_ru"]}.compact_blank.presence
      }.compact
    end

    def short_form(entry, prefix)
      text = entry[prefix].presence
      return if text.nil?

      pinyin = entry["#{prefix}_pinyin"].presence
      {
        "text" => text,
        "pinyin" => pinyin,
        "zhuyin" => (Zhuyin.from_pinyin(pinyin) if pinyin),
        "note" => {
          "en" => entry["#{prefix}_note_en"],
          "ru" => entry["#{prefix}_note_ru"]
        }.compact_blank.presence
      }.compact
    end
  end
end
