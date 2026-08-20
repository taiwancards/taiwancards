# frozen_string_literal: true

module Huayu
  class TaiwanEverydayImporter
    PATH = AppData.path("huayu/taiwan_everyday.json")
    SOURCE = "Taiwan everyday"
    COLLECTION = "Taiwan everyday"
    ORIGINS = %w[hokkien japanese internet abbreviation taiwan-mandarin].freeze
    REGISTERS = %w[neutral casual vulgar].freeze
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
    FACETS = %w[recognition production reading tone].freeze
    TAIGI_READINGS = %w[phonetic native].freeze
    DEFAULT_TIER = 2
    MIN_PRUNE_RATIO = 0.9

    Result = Data.define(:imported, :skipped, :dropped)

    def initialize(path: PATH)
      @path = path
      @upserter = Lexemes::Upserter.new
    end

    def call
      return Result.new(imported: 0, skipped: 0, dropped: 0) unless @path.exist?

      imported = 0
      skipped = 0
      kept = []

      entries.each_with_index do |entry, index|
        if valid?(entry)
          kept << import(entry, index).id
          imported += 1
        else
          skipped += 1
        end
      end

      dropped = prune(kept)
      Result.new(imported:, skipped:, dropped:)
    end

    private

    def entries
      JSON.parse(@path.read)
    end

    def prune(kept_ids)
      current = collection.collection_items.count
      return 0 if current.zero?
      return 0 if kept_ids.size < current * MIN_PRUNE_RATIO

      collection.collection_items.where.not(lexeme_id: kept_ids).destroy_all.size
    end

    def valid?(entry)
      entry["text"].present? &&
        entry["pinyin"].present? &&
        entry["en"].present? &&
        ORIGINS.include?(entry["origin"].to_s) &&
        REGISTERS.include?(entry["register"].to_s)
    end

    def import(entry, index)
      lexeme = @upserter.word(
        entry["text"],
        readings: {"pinyin" => entry["pinyin"], "zhuyin" => zhuyin_for(entry)},
        meanings: {"en" => entry["en"], "ru" => entry["ru"]},
        source: SOURCE
      )
      lexeme.data = lexeme.data.merge(metadata(entry))
      lexeme.save! if lexeme.changed?

      link_characters(lexeme)
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
          meanings: {"en" => entry["en"], "ru" => entry["ru"]}.compact_blank,
          source: SOURCE
        )
        counterpart = kind == "abbr" ? "full" : "abbr"
        variant.data = variant.data.merge(
          "variant_of" => lexeme.text,
          counterpart => back_reference(lexeme)
        )
        variant.save! if variant.changed?
        link_characters(variant)
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
        "tier" => entry["tier"].presence&.to_i || DEFAULT_TIER,
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
        "note" => {"en" => entry["note_en"], "ru" => entry["note_ru"]}.compact_blank.presence,
        "examples" => examples(entry),
        "abbr" => short_form(entry, "abbr"),
        "full" => short_form(entry, "full"),
        "capital" => capital(entry)
      }.compact
    end

    def examples(entry)
      rows = entry["examples"].presence || [entry["example"]].compact
      rows
        .filter_map { |row| row.slice("zh", "en", "ru").compact_blank.presence if row.is_a?(Hash) }
        .presence
    end

    def hokkien(entry)
      tailo = entry["tailo"].presence
      return if tailo.nil?

      {
        "tailo" => tailo,
        "hanzi" => entry["hokkien"].presence,
        "reading" => entry["taigi_reading"].presence_in(TAIGI_READINGS),
        "say" => {
          "zhuyin" => entry["say_zhuyin"].presence,
          "pinyin" => entry["say_pinyin"].presence
        }.compact_blank.presence
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

    def zhuyin_for(entry)
      entry["zhuyin"].presence || Zhuyin.from_pinyin(entry["pinyin"]).to_s
    end

    def link_characters(lexeme)
      children = lexeme.text.chars.filter_map { |char|
        Lexeme.find_by(kind: Lexeme.kinds[:character], text: char)
      }
      @upserter.link(lexeme, children) if children.size == lexeme.text.chars.size
    end

    def collection
      @collection ||= Collection
        .find_or_create_by!(kind: :everyday, name: COLLECTION, user_id: nil) { |record|
          record.position = 900
        }
    end
  end
end
