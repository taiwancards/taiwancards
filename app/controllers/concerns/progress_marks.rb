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

  def started_lexeme_ids(ids)
    remembered_among(ids).distinct.pluck(:lexeme_id).to_set
  end

  def known_lexeme_ids(ids)
    remembered_among(ids).where.not(state: :unseen).distinct.pluck(:lexeme_id).to_set
  end

  def token_lexeme_ids(lines)
    lines.flat_map { |_line, tokens| tokens.filter_map { |token| token.lexeme&.id } }.uniq
  end

  def remembered_among(ids)
    return LexemeMemory.none if ids.empty?

    LexemeMemory.owned_by(current_user).active.where(lexeme_id: ids)
  end
end
