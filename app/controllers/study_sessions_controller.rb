# frozen_string_literal: true

class StudySessionsController < ApplicationController
  MODES = %w[cram daily collection desk today redo].freeze
  RATINGS = %w[again hard good easy].freeze

  def show
    @mode = params[:mode].presence_in(MODES) || "daily"
    @run = Study::Run.start(mode: @mode, size: params[:size], collection: find_collection)
    session[:study] = @run.state
    load_current
  end

  def review
    state = session[:study] || {}
    grade_facet(params[:lexeme_id], params[:facet], params[:rating], params[:elapsed_ms], state["sid"])

    @run = Study::Run.resume(state)
    @mode = @run.mode
    load_current

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to(study_path(mode: @mode)) }
    end
  end

  private

  def load_current
    @total = @run.total
    @done = @run.done
    @remaining = @run.remaining
    @session_id = @run.session_id
    token = @run.head
    return if token.blank?

    lexeme_id, @facet = token.split(":")
    @lexeme = Lexeme.find_by(id: lexeme_id)
    @memory = @lexeme &&
      LexemeMemory.owned_by(Current.user).find_by(lexeme_id: @lexeme.id, facet: LexemeMemory.facets[@facet])
  end

  def find_collection
    return if params[:collection_id].blank?

    Collection.where(user_id: [nil, Current.user&.id]).find_by(id: params[:collection_id])
  end

  def grade_facet(lexeme_id, facet, rating, elapsed_ms, session_id)
    return if lexeme_id.blank? || facet.blank? || RATINGS.exclude?(rating)

    memory = LexemeMemory.owned_by(Current.user).find_by(lexeme_id:, facet: LexemeMemory.facets[facet])
    return if memory.nil?

    Lexemes::ReviewProcessor.new.call(
      memory,
      rating:,
      elapsed_ms: elapsed_ms.presence&.to_i,
      session_id: session_id.presence
    )
  end
end
