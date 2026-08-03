# frozen_string_literal: true

module Huayu
  class GrammarImporter
    SOURCE = "TBCL grammar"
    FACETS = %w[recognition].freeze

    Result = Data.define(:imported, :skipped, :voiced)

    def call
      lessons = GrammarLessons.taught
      return Result.new(imported: 0, skipped: 0, voiced: 0) if lessons.empty?

      imported = 0
      lessons.each do |lesson|
        import(lesson)
        imported += 1
      end

      Result.new(imported:, skipped: GrammarLessons.all.size - imported, voiced: mark_voiced_sentences)
    end

    private

    def import(lesson)
      lexeme = Lexeme.find_or_initialize_by(kind: Lexeme.kinds[:grammar], text: lesson.pattern)
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

    # A sentence card is only offered when the learner can hear it, so the manifest is
    # mirrored onto the rows themselves and the picker can stay in SQL.
    def mark_voiced_sentences
      texts = ListeningClips.all.map(&:text)
      return 0 if texts.empty?

      marked = 0
      texts.each_slice(2_000) do |slice|
        Lexeme.where(kind: :sentence, text: slice).find_each do |sentence|
          next if sentence.data["audio"] == "common_voice"

          sentence.update!(data: sentence.data.merge("audio" => "common_voice"))
          marked += 1
        end
      end

      marked
    end
  end
end
