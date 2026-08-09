# frozen_string_literal: true

module Huayu
  class PhraseDrillsImporter
    SOURCE = "Textbook Drills"
    PATH = Rails.root.join("data/huayu/phrase_drills.txt")
    COVERAGE = 0.95
    SCALES = {"tocfl" => SentenceProfile::TOCFL_LEVELS.length, "tbcl" => SentenceProfile::TBCL_GRADES.length}.freeze
    LINKABLE = %i[word collocation measure_word character].freeze

    def initialize(analyzer: TextAnalyzer.new)
      @analyzer = analyzer
    end

    def call(path = PATH)
      return {imported: 0, retired: 0, linked: 0} unless File.exist?(path)

      upserter = Lexemes::Upserter.new
      kept = []
      segments = {}

      File.foreach(path, chomp: true).with_index(1) do |line, position|
        text, en, ru = line.split("\t", 3).map { |part| part.to_s.strip }
        next if text.blank? || en.blank?

        units = @analyzer.segment(text)
        lexeme = upserter.phrase(
          text,
          meanings: {"en" => en, "ru" => ru}.compact_blank,
          source: SOURCE,
          data: {"drill" => position, "segments" => units}.merge(levels(units))
        )
        lexeme.update!(restricted: true) unless lexeme.restricted?
        kept << lexeme.id
        segments[lexeme.id] = units
      end

      retired = retire(kept)
      {imported: kept.size, retired:, linked: relink(segments)}
    end

    def self.drills
      Lexeme
        .where(kind: :phrase)
        .where("lexemes.data ->> 'drill' IS NOT NULL")
        .order(Arel.sql("(lexemes.data ->> 'drill')::int"))
    end

    private

    def levels(units)
      SCALES.each_with_object({}) do |(scale, ceiling), memo|
        placed = place(units, vocabulary.fetch(scale), ceiling)
        memo[scale] = placed[:index]
        memo["#{scale}_exact"] = placed[:exact]
      end
    end

    def place(units, table, ceiling)
      return {index: nil, exact: false} if units.empty?

      known = units.map { |unit| table[unit] }
      covered = known.compact
      return {index: nil, exact: false} if covered.empty?
      return {index: nil, exact: false} if covered.length.to_f / known.length < COVERAGE

      {index: [covered.max, ceiling].min, exact: covered.length == known.length}
    end

    def vocabulary
      @vocabulary ||= begin
        tocfl = {}
        tbcl = {}

        Lexeme.where(kind: %i[word character]).pluck(:text, :data).each do |text, data|
          position = SentenceProfile::TOCFL_LEVELS.index(data["tocfl_level"])
          tocfl[text] = position + 1 if position

          grade = data["tbcl_grade"]&.to_i
          tbcl[text] = grade if grade&.positive?
        end

        {"tocfl" => tocfl, "tbcl" => tbcl}
      end
    end

    def relink(segments)
      return 0 if segments.empty?

      entries = dictionary
      rows = segments.flat_map { |lexeme_id, units| links_for(lexeme_id, units, entries) }

      LexemeLink.where(parent_id: segments.keys).delete_all
      rows.each_slice(5_000) do |slice|
        LexemeLink.insert_all(slice, unique_by: :index_lexeme_links_on_parent_id_and_child_id_and_position)
      end

      LexemeLink.where(parent_id: segments.keys).count
    end

    def links_for(lexeme_id, units, entries)
      position = 0

      units.flat_map { |unit| entries.key?(unit) ? [unit] : unit.chars }.filter_map do |token|
        child_id = entries[token]
        next if child_id.nil?

        row = {parent_id: lexeme_id, child_id:, position:}
        position += 1
        row
      end
    end

    def dictionary
      @dictionary ||= Lexeme
        .where(kind: LINKABLE)
        .order(Arel.sql("(kind = #{Lexeme.kinds.fetch("character")}) DESC"))
        .pluck(:text, :id)
        .to_h
    end

    def retire(kept)
      retired = 0

      self.class.drills.where.not(id: kept).reorder(nil).find_each do |lexeme|
        if lexeme.sources == [SOURCE]
          lexeme.destroy!
        else
          lexeme.update!(data: lexeme.data.except("drill"), sources: lexeme.sources - [SOURCE])
        end

        retired += 1
      end

      retired
    end
  end
end
