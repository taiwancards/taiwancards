# frozen_string_literal: true

module Huayu
  class CuratedPageImporter
    ORIGINS = %w[hokkien japanese internet abbreviation taiwanese-mandarin].freeze
    REGISTERS = %w[neutral casual vulgar].freeze
    FACETS = %w[recognition production reading tone].freeze
    TAIGI_READINGS = %w[phonetic native].freeze
    DEFAULT_TIER = 2
    MIN_PRUNE_RATIO = 0.9

    Result = Data.define(:imported, :skipped, :dropped)

    def initialize(path: self.class::PATH)
      @path = Pathname(path)
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

      Result.new(imported:, skipped:, dropped: prune(kept))
    end

    private

    def entries = JSON.parse(@path.read)

    def prune(kept_ids)
      current = collection.collection_items.count
      return 0 if current.zero?
      return 0 if kept_ids.size < current * MIN_PRUNE_RATIO

      collection.collection_items.where.not(lexeme_id: kept_ids).destroy_all.size
    end

    def valid?(entry)
      entry["text"].present? && entry["pinyin"].present? && entry["en"].present? && accepted?(entry)
    end

    def accepted?(entry)
      (entry["origin"].blank? || ORIGINS.include?(entry["origin"].to_s)) &&
        (entry["register"].blank? || REGISTERS.include?(entry["register"].to_s))
    end

    def import(entry, index)
      guarded = guarded?(entry["text"])
      lexeme = @upserter.word(
        entry["text"],
        readings: guarded ? {} : readings(entry),
        meanings: guarded ? {} : meanings(entry),
        source: self.class::SOURCE
      )
      lexeme.data = merged_data(lexeme, entry, guarded)
      lexeme.save! if lexeme.changed?

      @upserter.link_characters(lexeme)
      collection.add_lexeme(lexeme, position: index)
      lexeme
    end

    def readings(entry) = {"pinyin" => entry["pinyin"], "zhuyin" => zhuyin_for(entry)}

    def meanings(entry) = {"en" => entry["en"], "ru" => entry["ru"]}

    def guarded?(text)
      existing = Lexeme.where(kind: Lexeme::DICTIONARY_KINDS, text:).order(:kind).first
      existing.present? && existing.data["placements"].present?
    end

    def merged_data(lexeme, entry, guarded)
      data = lexeme.data.merge(payload(entry))
      refresh_examples(data, entry, guarded)
      shared_metadata(entry).each do |key, value|
        next if guarded && data[key].present?

        data[key] = value
      end

      data.compact
    end

    def payload(_entry) = {}

    def refresh_examples(_data, _entry, _guarded) = nil

    def shared_metadata(entry)
      {
        "origin" => entry["origin"].presence || "taiwanese-mandarin",
        "register" => entry["register"].presence || "neutral",
        "tier" => tier(entry),
        "facets" => FACETS,
        "taiwan_only" => (true if entry["marked"]),
        "china" => entry["china"].presence,
        "note" => note(entry)
      }
    end

    def note(entry) = {"en" => entry["note_en"], "ru" => entry["note_ru"]}.compact_blank.presence

    def examples(entry)
      rows = entry["examples"].presence || [entry["example"]].compact
      rows
        .filter_map { |row| row.slice("zh", "en", "ru").compact_blank.presence if row.is_a?(Hash) }
        .presence
    end

    def examples_union(current, fresh)
      (Array(current) + Array(fresh)).uniq { |row| row["zh"] }.presence
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

    def tier(entry) = entry["tier"].presence&.to_i || DEFAULT_TIER

    def zhuyin_for(entry) = entry["zhuyin"].presence || Zhuyin.from_pinyin(entry["pinyin"]).to_s

    def collection
      @collection ||= Collection
        .find_or_create_by!(kind: self.class::COLLECTION_KIND, name: self.class::COLLECTION, user_id: nil) do |record|
          record.position = self.class::COLLECTION_POSITION
        end
    end
  end
end
