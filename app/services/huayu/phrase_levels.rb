# frozen_string_literal: true

module Huayu
  class PhraseLevels
    SCALES = {"tocfl" => SentenceProfile::TOCFL_LEVELS.length, "tbcl" => SentenceProfile::TBCL_GRADES.length}.freeze
    LINKABLE = %i[word collocation measure_word character].freeze
    BATCH = 2_000

    def initialize(io: $stdout, analyzer: TextAnalyzer.new)
      @io = io
      @analyzer = analyzer
    end

    def call
      graded = Hash.new(0)
      patches = []
      links = []

      Lexeme.practice_phrases.order(:id).pluck(:id, :text, :data).each do |id, text, data|
        units = @analyzer.segment(text)
        next if units.empty?

        placed = levels(units)
        SCALES.each_key { |scale| graded[scale] += 1 if placed[scale] }
        links << [id, units]

        patch = placed.merge("segments" => units)
        patches << [id, patch] unless patch.all? { |key, value| data[key] == value }
      end

      updated = Bulk.patch(
        target: "lexemes",
        columns: {"patch" => "jsonb"},
        rows: patches,
        set: "data = lexemes.data || bulk_patch.patch"
      )

      linked = relink(links)
      report(links.length, updated, graded, linked)
      {phrases: links.length, updated:, linked:, **graded.symbolize_keys}
    end

    private

    def levels(units)
      SCALES.each_key.with_object({}) do |scale, memo|
        placed = vocabulary.fetch(scale).place(units)
        memo[scale] = placed.index
        memo["#{scale}_exact"] = placed.exact
      end
    end

    def vocabulary
      @vocabulary ||= Lexemes::LevelScale.vocabulary
    end

    def relink(entries)
      return 0 if entries.empty?

      dictionary = entries_by_text
      rows = entries.flat_map { |id, units| links_for(id, units, dictionary) }

      entries.map(&:first).each_slice(BATCH) { |slice| LexemeLink.where(parent_id: slice).delete_all }
      rows.each_slice(5_000) do |slice|
        LexemeLink.insert_all(slice, unique_by: :index_lexeme_links_on_parent_id_and_child_id_and_position)
      end

      rows.length
    end

    def links_for(lexeme_id, units, dictionary)
      seen = Set.new
      position = 0

      units.flat_map { |unit| [unit, *unit.chars] }.filter_map do |token|
        child_id = dictionary[token]
        next if child_id.nil? || !seen.add?(child_id)

        row = {parent_id: lexeme_id, child_id:, position:}
        position += 1
        row
      end
    end

    def entries_by_text
      Lexeme
        .where(kind: LINKABLE)
        .order(Arel.sql("(kind = #{Lexeme.kinds.fetch("character")}) DESC"))
        .pluck(:text, :id)
        .to_h
    end

    def report(total, updated, graded, linked)
      @io.puts(format("practice phrases     : %6d", total))
      SCALES.each_key { |scale| @io.puts(format("  %-18s : %6d graded", scale, graded[scale])) }
      @io.puts(format("  rows updated       : %6d", updated))
      @io.puts(format("  dictionary links   : %6d", linked))
    end
  end
end
