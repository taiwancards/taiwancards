# frozen_string_literal: true

module Huayu
  class MedicineImporter
    PATH = AppData.path("huayu/medicine.json")
    SOURCE = "Taiwan medicine"
    COLLECTION = "Taiwan medicine"
    ORIGINS = TaiwanEverydayImporter::ORIGINS
    REGISTERS = TaiwanEverydayImporter::REGISTERS
    CATEGORIES = %w[body organs symptoms diseases vaccines hospital departments treatment people nhi].freeze
    FACETS = TaiwanEverydayImporter::FACETS
    TAIGI_READINGS = TaiwanEverydayImporter::TAIGI_READINGS
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
        CATEGORIES.include?(entry["category"].to_s) &&
        (entry["origin"].blank? || ORIGINS.include?(entry["origin"].to_s)) &&
        (entry["register"].blank? || REGISTERS.include?(entry["register"].to_s))
    end

    def import(entry, index)
      guarded = guarded?(entry["text"])
      lexeme = @upserter.word(
        entry["text"],
        readings: guarded ? {} : {"pinyin" => entry["pinyin"], "zhuyin" => zhuyin_for(entry)},
        meanings: guarded ? {} : {"en" => entry["en"], "ru" => entry["ru"]},
        source: SOURCE
      )
      lexeme.data = merged_data(lexeme, entry, guarded)
      lexeme.save! if lexeme.changed?

      link_characters(lexeme)
      collection.add_lexeme(lexeme, position: index)
      lexeme
    end

    def guarded?(text)
      existing = Lexeme.where(kind: Lexeme::DICTIONARY_KINDS, text:).order(:kind).first
      existing.present? && existing.data["placements"].present?
    end

    def merged_data(lexeme, entry, guarded)
      data = lexeme.data.merge("med" => med(entry))
      fresh = examples(entry)
      data["examples"] = guarded ? examples_union(data["examples"], fresh) : fresh
      shared_metadata(entry).each do |key, value|
        next if guarded && data[key].present?

        data[key] = value
      end

      data.compact
    end

    def med(entry)
      {
        "category" => entry["category"],
        "tier" => tier(entry),
        "folk" => entry["folk"].presence,
        "formal" => entry["formal"].presence
      }.compact
    end

    def shared_metadata(entry)
      {
        "origin" => entry["origin"].presence || "taiwan-mandarin",
        "register" => entry["register"].presence || "neutral",
        "tier" => tier(entry),
        "facets" => FACETS,
        "taiwan_only" => (true if entry["marked"]),
        "china" => entry["china"].presence,
        "hokkien" => hokkien(entry),
        "note" => {"en" => entry["note_en"], "ru" => entry["note_ru"]}.compact_blank.presence
      }
    end

    def examples(entry)
      rows = entry["examples"].presence || [entry["example"]].compact
      rows
        .filter_map { |row| row.slice("zh", "en", "ru").compact_blank.presence if row.is_a?(Hash) }
        .presence
    end

    def examples_union(current, fresh)
      rows = Array(current) + Array(fresh)
      rows.uniq { |row| row["zh"] }.presence
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

    def tier(entry)
      entry["tier"].presence&.to_i || DEFAULT_TIER
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
        .find_or_create_by!(kind: :medicine, name: COLLECTION, user_id: nil) { |record|
          record.position = 910
        }
    end
  end
end
