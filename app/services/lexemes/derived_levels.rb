# frozen_string_literal: true

module Lexemes
  class DerivedLevels
    KINDS = %i[word collocation].freeze
    SCALES = {
      "tocfl" => SentenceProfile::TOCFL_LEVELS.length,
      "tbcl" => SentenceProfile::TBCL_GRADES.length
    }.freeze

    def initialize(io: $stdout, analyzer: Huayu::TextAnalyzer.new)
      @io = io
      @analyzer = analyzer
    end

    def call
      graded = Hash.new(0)
      exact = Hash.new(0)
      patches = []
      seen = 0

      Lexeme.where(kind: KINDS).order(:id).pluck(:id, :text, :data).each do |id, text, data|
        units = @analyzer.segment(text, excluding: text)
        next if units.empty?

        seen += 1
        placed = levels(units, text)
        SCALES.each_key do |scale|
          graded[scale] += 1 if placed[scale]
          exact[scale] += 1 if placed["#{scale}_exact"]
        end

        patches << [id, placed] unless placed.all? { |key, value| data[key] == value }
      end

      updated = Bulk.patch(
        target: "lexemes",
        columns: {"patch" => "jsonb"},
        rows: patches,
        set: "data = lexemes.data || bulk_patch.patch"
      )

      report(seen, updated, graded, exact)
      {entries: seen, updated:, **graded.symbolize_keys}
    end

    private

    def levels(units, text)
      SCALES.each_key.with_object({}) do |scale, memo|
        placed = vocabulary.fetch(scale).place(units, excluding: text)
        memo[scale] = placed.index
        memo["#{scale}_exact"] = placed.exact
      end
    end

    def vocabulary
      @vocabulary ||= LevelScale.vocabulary
    end

    def report(seen, updated, graded, exact)
      @io.puts(format("words and collocations : %6d", seen))
      SCALES.each_key do |scale|
        @io.puts(format("  %-20s : %6d graded, %6d exact", scale, graded[scale], exact[scale]))
      end

      @io.puts(format("  rows updated         : %6d", updated))
    end
  end
end
