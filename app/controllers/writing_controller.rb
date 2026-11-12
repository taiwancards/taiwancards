# frozen_string_literal: true

class WritingController < ApplicationController
  include PracticeQueue

  QUEUE_SIZE = 30
  QUEUE_SLOT = "writing_practice"
  MISTAKE_WINDOW_DAYS = 30

  before_action :load_scope

  def show
    @lexeme = pick_lexeme
    @target = @lexeme && Huayu::WritingTarget.new(@lexeme)
    @chars = @target ? @target.chars : []
    @advance_url = writing_path(next_params(advance: 1))
    @first_time = @lexeme.present? && first_time?(@lexeme)
  end

  def grade
    lexeme = writable_scope.find_by(id: params[:lexeme_id])
    return head(:not_found) if lexeme.nil?

    rating = params[:rating].to_s
    return head(:unprocessable_content) if Study::Run::RATINGS.exclude?(rating)

    memory = Lexemes::Activator.new(user: current_user).activate(lexeme, :writing)
    Lexemes::ReviewProcessor.new.call(
      memory,
      rating:,
      elapsed_ms: params[:elapsed_ms].presence&.to_i,
      session_id: params[:session_id].presence
    )
    head(:ok)
  end

  private

  def first_time?(lexeme)
    !LexemeMemory.owned_by(current_user).exists?(lexeme:, facet: LexemeMemory.facets[:writing])
  end

  def load_scope
    @collection = Collection.studyable_by(current_user).find_by(id: params[:collection_id])
  end

  def next_params(extra = {})
    {collection_id: @collection&.id}.compact.merge(extra)
  end

  def writable_scope
    scope = Lexeme.where(kind: %i[character word])
    scope = scope.where(id: @collection.lexemes.select(:id)) if @collection
    scope
  end

  def pick_lexeme
    return writable_scope.find_by(id: params[:lexeme_id]) if params[:lexeme_id].present?

    queue, position = practice_queue(QUEUE_SLOT, deck: @collection&.id) { build_queue }
    first_writable(queue, position)
  end

  def first_writable(queue, position)
    remaining = queue.drop(position)
    return nil if remaining.empty?

    found = writable_scope.where(id: remaining).index_by(&:id)
    remaining.each_with_index do |id, offset|
      lexeme = found[id]
      next if lexeme.nil? || !Huayu::WritingTarget.new(lexeme).writable?

      move_practice_position(QUEUE_SLOT, position + offset)
      return lexeme
    end

    nil
  end

  def build_queue
    mistakes = mistake_lexeme_ids
    fresh = writable_scope
      .where
      .not(id: mistakes)
      .order(order_by_difficulty)
      .limit(QUEUE_SIZE * 3)
      .pluck(:id)
    candidates = mistakes + fresh
    texts = writable_scope.where(id: candidates).pluck(:id, :text).to_h
    candidates.select { |id| Huayu::WritingTarget.writable?(texts[id]) }.first(QUEUE_SIZE)
  end

  def order_by_difficulty
    if @collection
      Arel.sql("#{Lexeme::FREQ_RANK_SQL} NULLS LAST, #{Lexeme::MOE_INDEX_SQL} NULLS LAST, RANDOM()")
    else
      Arel.sql(
        "#{Lexeme::FREQ_RANK_SQL} NULLS LAST, char_length(text) ASC, #{Lexeme::MOE_INDEX_SQL} NULLS LAST, text ASC"
      )
    end
  end

  def mistake_lexeme_ids
    ids = LexemeReview
      .owned_by(current_user)
      .where(facet: LexemeMemory.facets[:writing], rating: [1, 2])
      .where(reviewed_at: MISTAKE_WINDOW_DAYS.days.ago..)
      .order(Arel.sql("rating DESC"), reviewed_at: :desc)
      .pluck(:lexeme_id)
      .uniq
    writable_scope.where(id: ids).pluck(:id).to_set.then { |allowed| ids.select { |id| allowed.include?(id) } }
  end
end
