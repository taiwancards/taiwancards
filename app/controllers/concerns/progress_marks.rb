# frozen_string_literal: true

module ProgressMarks
  extend ActiveSupport::Concern

  private

  def load_progress(lexemes)
    ids = Array(lexemes).map(&:id)
    rows = ids.empty? ? [] : LexemeMemory
      .owned_by(Current.user)
      .where(lexeme_id: ids)
      .pluck(:lexeme_id, :activated_at, :state)

    @started_ids = rows.filter_map { |id, activated_at, _| id if activated_at }.to_set
    @known_ids = rows.filter_map { |id, _, state| id if state == "review" }.to_set
  end
end
