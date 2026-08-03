# frozen_string_literal: true

module Huayu
  class GrammarImporter
    SOURCE = "TBCL grammar"
    FACETS = %w[recognition].freeze

    Result = Data.define(:imported, :skipped, :dropped)

    def call
      lessons = GrammarLessons.taught
      return Result.new(imported: 0, skipped: 0, dropped: 0) if lessons.empty?

      @shared = lessons.group_by(&:pattern).select { |_, group| group.size > 1 }.keys.to_set
      lessons.each { |lesson| import(lesson) }

      Result.new(
        imported: lessons.size,
        skipped: GrammarLessons.all.size - lessons.size,
        dropped: prune(lessons.map { |lesson| key_for(lesson) })
      )
    end

    private

    def key_for(lesson)
      @shared.include?(lesson.pattern) ? "#{lesson.pattern}（#{lesson.head}）" : lesson.pattern
    end

    def prune(keys)
      stale = Lexeme.where(kind: :grammar).where.not(text: keys)
      return 0 if stale.empty?

      LexemeMemory.where(lexeme_id: stale.select(:id)).delete_all
      stale.destroy_all.size
    end

    def import(lesson)
      lexeme = Lexeme.find_or_initialize_by(kind: Lexeme.kinds[:grammar], text: key_for(lesson))
      lexeme.meanings = lexeme.meanings.merge(
        "en" => lesson.title(:en),
        "ru" => lesson.title(:ru)
      )
      lexeme.data = lexeme.data.merge(
        "tbcl_grade" => lesson.level,
        "grammar_slug" => lesson.slug,
        "head" => lesson.head,
        "facets" => FACETS
      )
      lexeme.add_source(SOURCE)
      lexeme.save! if lexeme.changed?
      lexeme
    end
  end
end
