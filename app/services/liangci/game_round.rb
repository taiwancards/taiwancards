# frozen_string_literal: true

module Liangci
  class GameRound
    OPTIONS = 4
    POOL = 40
    DISTRACTOR_POOL = 30

    def initialize(user)
      @user = user
    end

    def call
      noun = pick_noun
      return nil if noun.nil?

      correct = correct_for(noun)
      return nil if correct.nil?

      options = ([correct] + distractors(noun, correct)).shuffle
      {noun:, correct: correct.text, options: directions(options, correct)}
    end

    private

    def directions(options, correct)
      options.zip(%w[up right down left]).map do |entry, direction|
        {direction:, entry:, correct: entry.id == correct.id}
      end
    end

    def pick_noun
      @noun ||= (started_nouns.sample || easiest_nouns.sample)
    end

    def nouns
      Lexeme.visible.where(kind: %i[word character]).where("data ? 'classifiers'")
    end

    def started_nouns
      return [] if @user.nil?

      nouns.where(id: LexemeMemory.owned_by(@user).active.select(:lexeme_id)).order(:score).limit(POOL).to_a
    end

    def easiest_nouns
      nouns.order(Arel.sql("lexemes.score NULLS LAST")).limit(POOL).to_a
    end

    def correct_for(noun)
      main = Array(noun.data["classifiers"]).find { |row| row["main"] } || Array(noun.data["classifiers"]).first
      return nil if main.nil?

      @correct_text = main["text"]
      measure_words.find_by(text: main["text"])
    end

    def distractors(noun, correct)
      taken = Array(noun.data["classifiers"]).map { |row| row["text"] } + [correct.text]
      measure_words
        .where
        .not(text: taken)
        .order(:score)
        .limit(DISTRACTOR_POOL)
        .to_a
        .sample(OPTIONS - 1)
    end

    def measure_words
      Lexeme.where(kind: :measure_word)
    end
  end
end
