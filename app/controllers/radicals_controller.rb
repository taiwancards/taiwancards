# frozen_string_literal: true

class RadicalsController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  include ProgressMarks

  def index
    @radicals = Lexeme.where(kind: :radical).order(Arel.sql("(data ->> 'number')::int"))
    @counts = ContentCache.fetch("radicals/counts") { character_counts }
  end

  def show
    @radical = Lexeme.find_by!(kind: :radical, text: params[:text])
    @characters = Lexeme.under_radical(@radical.data["number"]).frequency_order
    @studied_ids = started_lexeme_ids(@characters.map(&:id))
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
