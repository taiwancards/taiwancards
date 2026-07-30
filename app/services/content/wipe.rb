# frozen_string_literal: true

module Content
  PRESERVED_KINDS = %w[character word radical].freeze

  class Wipe
    def initialize(full: false, io: $stdout)
      @full = full
      @io = io
    end

    def call
      derived = Lexeme.where(kind: %i[sentence collocation phrase measure_word])

      SentenceProfile.delete_all
      SentenceWord.delete_all
      SenseExample.delete_all
      LexemeSense.delete_all
      LexemeContentSource.delete_all
      MainlandMarker.delete_all

      LexemeLink.where(parent_id: derived.select(:id)).delete_all
      LexemeLink.where(child_id: derived.select(:id)).delete_all
      CollectionItem.where(lexeme_id: derived.select(:id)).delete_all
      derived.delete_all

      return refreshed unless @full

      LexemeReview.delete_all
      LexemeMemory.delete_all
      PronunciationAttempt.delete_all
      SyllableSkill.delete_all
      ActivityEvent.delete_all
      LexemeLink.delete_all
      CollectionItem.delete_all
      Lexeme.delete_all
      Collection.delete_all
      ContentSource.delete_all

      VoiceProfile.delete_all
      StudyPlan.delete_all
      PlacementTest.delete_all
      User.delete_all

      wiped
    end

    private

    def refreshed
      LexemeLink.where(parent_id: Lexeme.where(kind: PRESERVED_KINDS).select(:id)).delete_all
      @io.puts("   kept characters and words: #{Lexeme.where(kind: PRESERVED_KINDS).count}")
      @io.puts("   kept cards: #{LexemeMemory.count}")
      :refreshed
    end

    def wiped
      Lexeme.connection.execute("ALTER SEQUENCE lexemes_id_seq RESTART WITH 1")
      @io.puts(
        "   everything removed, including root entities and progress; ids restarted"
      )
      :wiped
    end
  end
end
