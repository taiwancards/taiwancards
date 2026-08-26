# frozen_string_literal: true

module Huayu
  class GamesImporter
    PATH = AppData.path("huayu/games.json")
    SOURCE = "Taiwan games"
    COLLECTION = "Taiwan games"
    ORIGINS = TaiwanEverydayImporter::ORIGINS
    REGISTERS = TaiwanEverydayImporter::REGISTERS
    GAMES = %w[mahjong mcr xiangqi go tabletop].freeze
    CATEGORIES = %w[
      game
      board
      piece
      equipment
      roles
      procedure
      meld
      call
      wait
      scoring
      pattern
      tactic
      opening
      endgame
      strategy
      rule
      rank
      talk
    ]
      .freeze
    FACETS = TaiwanEverydayImporter::FACETS
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
        GAMES.include?(entry["game"].to_s) &&
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
      data = lexeme.data.merge("game" => game(entry))
      shared_metadata(entry).each do |key, value|
        next if guarded && data[key].present?

        data[key] = value
      end

      data.compact
    end

    def game(entry)
      {
        "name" => entry["game"],
        "category" => entry["category"],
        "tier" => tier(entry)
      }
    end

    def shared_metadata(entry)
      {
        "origin" => entry["origin"].presence || "taiwanese-mandarin",
        "register" => entry["register"].presence || "neutral",
        "tier" => tier(entry),
        "facets" => FACETS,
        "taiwan_only" => (true if entry["marked"]),
        "china" => entry["china"].presence,
        "note" => {"en" => entry["note_en"], "ru" => entry["note_ru"]}.compact_blank.presence
      }
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
      @collection ||= Collection.find_or_create_by!(kind: :games, user: nil) { |row| row.name = COLLECTION }
    end
  end
end
