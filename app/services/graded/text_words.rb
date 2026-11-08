# frozen_string_literal: true

module Graded
  class TextWords
    def initialize(tokens, user:)
      @lexemes = Array(tokens).filter_map(&:lexeme).uniq(&:id)
      @user = user
    end

    def total = @lexemes.size

    def saved_ids
      @saved_ids ||= LexemeMemory
        .owned_by(@user)
        .active
        .where(lexeme_id: @lexemes.map(&:id))
        .distinct
        .pluck(:lexeme_id)
        .to_set
    end

    def saved_count = saved_ids.size

    def fresh = @lexemes.reject { |lexeme| saved_ids.include?(lexeme.id) }

    def add_fresh
      words = fresh
      Lexemes::Activator.new(user: @user).call_many(words)
      words.size
    end
  end
end
