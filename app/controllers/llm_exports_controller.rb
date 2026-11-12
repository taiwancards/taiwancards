# frozen_string_literal: true

class LlmExportsController < ApplicationController
  MATURE_STABILITY_DAYS = 21

  def show
    memories = LexemeMemory.owned_by(current_user).to_a.group_by(&:lexeme_id)
    studied = memories.select { |_, rows| rows.any?(&:activated_at) }
    lexemes = Lexeme.where(id: studied.keys).select(:id, :text, :meanings, :data)
    known, learning = lexemes.partition { |lexeme| mature?(studied.fetch(lexeme.id)) }

    render(
      json: {
        exported_at: Time.current.iso8601,
        known_words: known.map { |lexeme| word_payload(lexeme) },
        learning_words: learning.map { |lexeme| word_payload(lexeme) }
      }
    )
  end

  private

  def mature?(memories)
    reviewed = memories.select(&:state_review?)
    reviewed.any? && reviewed.all? { |memory| memory.stability.to_f >= MATURE_STABILITY_DAYS }
  end

  def word_payload(lexeme)
    {word: lexeme.text, translation: lexeme.meaning, level: lexeme.data["tocfl_level"]}.compact
  end
end
