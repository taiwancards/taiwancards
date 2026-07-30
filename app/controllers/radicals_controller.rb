# frozen_string_literal: true

class RadicalsController < ApplicationController
  def index
    @radicals = Lexeme.where(kind: :radical).order(Arel.sql("(data ->> 'number')::int"))
    @counts = ContentCache.fetch("radicals/counts") { character_counts }
  end

  def show
    @radical = Lexeme.find_by!(kind: :radical, text: params[:text])
    number = @radical.data["number"]
    @characters = Lexeme
      .where(kind: :character)
      .where("(data ->> 'radical_number')::int = ?", number)
      .frequency_order
    @studied_ids = LexemeMemory
      .owned_by(Current.user)
      .where(lexeme_id: @characters.map(&:id))
      .where
      .not(activated_at: nil)
      .distinct
      .pluck(:lexeme_id)
      .to_set
  end

  private

  def character_counts
    Lexeme
      .where(kind: :character)
      .where("data ->> 'radical_number' IS NOT NULL")
      .group(Arel.sql("(data ->> 'radical_number')::int"))
      .count
  end
end
