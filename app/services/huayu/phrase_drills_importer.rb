# frozen_string_literal: true

module Huayu
  class PhraseDrillsImporter
    SOURCE = "Textbook Drills"
    PATH = Rails.root.join("data/huayu/phrase_drills.txt")

    def call(path = PATH)
      return {imported: 0, retired: 0} unless File.exist?(path)

      upserter = Lexemes::Upserter.new
      kept = []

      File.foreach(path, chomp: true).with_index(1) do |line, position|
        text, en, ru = line.split("\t", 3).map { |part| part.to_s.strip }
        next if text.blank? || en.blank?

        lexeme = upserter.phrase(
          text,
          meanings: {"en" => en, "ru" => ru}.compact_blank,
          source: SOURCE,
          data: {"drill" => position}
        )
        lexeme.update!(restricted: true) unless lexeme.restricted?
        kept << lexeme.id
      end

      {imported: kept.size, retired: retire(kept)}
    end

    def self.drills
      Lexeme
        .where(kind: :phrase)
        .where("lexemes.data ->> 'drill' IS NOT NULL")
        .order(Arel.sql("(lexemes.data ->> 'drill')::int"))
    end

    private

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
