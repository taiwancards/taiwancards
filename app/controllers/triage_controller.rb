# frozen_string_literal: true

class TriageController < ApplicationController
  BATCH = 40

  def show
    @kind = params[:kind].to_s.presence_in(%w[character word]) || "character"
    @items = batch
    @remaining = untouched.count
  end

  def create
    known = lexemes_from(params[:known])
    normal = lexemes_from(params[:normal])

    marker = Lexemes::KnownMarker.new(current_user)
    result = marker.call(known)
    marker.keep_normal(normal)

    render(json: {marked: result[:marked], kept: normal.size})
  end

  private

  def lexemes_from(ids)
    ids = Array(ids).map(&:to_i).reject(&:zero?).first(500)
    return [] if ids.empty?

    Lexeme.where(id: ids).to_a
  end

  def batch
    untouched.curriculum_order.limit(BATCH).to_a
  end

  def untouched
    touched = LexemeMemory
      .owned_by(current_user)
      .where
      .not(state: LexemeMemory.states[:unseen])
      .select(:lexeme_id)

    Lexeme
      .visible
      .where(kind: @kind)
      .where
      .not(id: touched)
  end
end
