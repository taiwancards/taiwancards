# frozen_string_literal: true

class LlmExportsController < ApplicationController
  MATURE_STABILITY_DAYS = 21

  def show
    lexemes = Lexeme
      .joins(:memories)
      .merge(LexemeMemory.active.owned_by(current_user))
      .includes(:memories)
      .distinct

    known, learning = lexemes.partition { |lexeme| mature?(lexeme) }

    render(
      json: {
        exported_at: Time.current.iso8601,
        known_words: known.map { |lexeme| word_payload(lexeme) },
        learning_words: learning.map { |lexeme| word_payload(lexeme) }
      }
    )
  end

  private

  def mature?(lexeme)
    memories = lexeme.memories.select { |memory| memory.user_id == current_user&.id && memory.state_review? }
    memories.any? && memories.all? { |memory| memory.stability.to_f >= MATURE_STABILITY_DAYS }
  end

  def word_payload(lexeme)
    {word: lexeme.text, translation: lexeme.meaning, level: lexeme.data["tocfl_level"]}.compact
  end
end
