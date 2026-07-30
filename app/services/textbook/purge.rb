# frozen_string_literal: true

module Textbook
  class Purge
    PREFIX = "Textbook"

    def initialize(io: $stdout)
      @io = io
    end

    def call(dry_run: false)
      phrases = Lexeme.where(kind: %i[phrase sentence collocation]).select { |l| textbook?(l) }
      tagged = Lexeme.where(kind: %i[word character radical]).select { |l| textbook?(l) }
      lessons = TextbookLesson.count

      report(phrases, tagged, lessons)
      return {phrases: phrases.size, retagged: tagged.size} if dry_run

      ActiveRecord::Base.transaction do
        ids = phrases.map(&:id)
        LexemeLink.where(parent_id: ids).or(LexemeLink.where(child_id: ids)).delete_all
        CollectionItem.where(lexeme_id: ids).delete_all
        Lexeme.where(id: ids).delete_all

        tagged.each do |lexeme|
          lexeme.update_columns(sources: lexeme.sources.reject { |s| s.to_s.start_with?(PREFIX) })
        end
      end

      @io.puts("Done. Words and characters removed: 0.")
      {phrases: phrases.size, retagged: tagged.size}
    end

    private

    def textbook?(lexeme)
      Array(lexeme.sources).any? { |source| source.to_s.start_with?(PREFIX) }
    end

    def report(phrases, tagged, lessons)
      sentences = phrases.count { |l| l.data["sentence"].to_s == "true" || l.sentence? }
      @io.puts(
        format(
          "sentences and phrases to remove : %6d (sentences among them %d)",
          phrases.size,
          sentences
        )
      )
      @io.puts(format("words and characters losing the tag : %6d", tagged.size))
      @io.puts(format("rows in textbook_lessons (untouched here) : %6d", lessons))
    end
  end
end
