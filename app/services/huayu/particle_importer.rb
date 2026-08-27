# frozen_string_literal: true

module Huayu
  class ParticleImporter
    PATH = AppData.path("huayu/particles.json")
    SOURCE = "Mood particles"
    FAMILIES = ZhuciController::FAMILIES
    OWNED = %w[rank corpus family sole_sense grammar variants force body warning examples].freeze

    Result = Data.define(:imported, :skipped, :dropped)

    def initialize(path: PATH)
      @path = path
    end

    def call
      return Result.new(imported: 0, skipped: 0, dropped: 0) unless @path.exist?

      kept = []
      skipped = 0

      entries.each do |entry|
        next skipped += 1 unless valid?(entry)

        kept << upsert(entry).id
      end

      dropped = Lexeme.where(kind: :particle).where.not(id: kept).destroy_all.size
      TextAnalyzer.reset_vocabulary! if dropped.positive? || kept.any?
      Result.new(imported: kept.size, skipped:, dropped:)
    end

    private

    def entries
      JSON.parse(@path.read)
    end

    def valid?(entry)
      entry["text"].present? &&
        entry["pinyin"].present? &&
        entry["summary_en"].present? &&
        entry["rank"].to_i.positive? &&
        FAMILIES.include?(entry["family"].to_s)
    end

    def upsert(entry)
      lexeme = Lexeme.find_or_initialize_by(kind: Lexeme.kinds[:particle], text: entry["text"])
      lexeme.readings = {"pinyin" => entry["pinyin"], "zhuyin" => entry["zhuyin"]}.compact_blank
      lexeme.meanings = {"en" => entry["summary_en"], "ru" => entry["summary_ru"]}.compact_blank
      lexeme.data = lexeme.data.except(*OWNED).merge(metadata(entry))
      lexeme.add_source(SOURCE)
      lexeme.save! if lexeme.changed?
      lexeme
    end

    def metadata(entry)
      {
        "rank" => entry["rank"].to_i,
        "corpus" => entry["corpus"].to_i,
        "family" => entry["family"],
        "sole_sense" => entry.fetch("sole_sense", false),
        "grammar" => entry["grammar"].presence,
        "variants" => entry["variants"].presence,
        "force" => localised(entry, "force"),
        "body" => localised(entry, "body"),
        "warning" => localised(entry, "warning"),
        "examples" => entry["examples"].presence
      }.compact
    end

    def localised(entry, key)
      {"en" => entry["#{key}_en"], "ru" => entry["#{key}_ru"]}.compact_blank.presence
    end
  end
end
