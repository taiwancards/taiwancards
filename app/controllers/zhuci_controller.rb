# frozen_string_literal: true

class ZhuciController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  FAMILIES = %w[core mood taiwan limiting cluster].freeze

  def index
    all = ordered
    @counts = all.group_by { |entry| entry.data["family"] }.transform_values(&:size)
    @family = params[:family].presence_in(FAMILIES)
    @entries = @family ? all.select { |entry| entry.data["family"] == @family } : all
    @total = all.size
  end

  def show
    @entry = Lexeme.find_by(kind: :particle, text: params[:text])
    return redirect_to(zhuci_entry_path(@entry.text)) if @entry.nil? && (@entry = Zhuci::Finder.call(params[:text]))
    return render(:missing, status: :not_found) if @entry.nil?

    @character = Lexeme.visible.find_by(kind: %i[character radical], text: @entry.text)
    @word = word_beyond_particle(@entry)
    @lesson = Huayu::GrammarLessons.find(@entry.data["grammar"]) if @entry.data["grammar"].present?
    @neighbours = neighbours_of(@entry)
  end

  private

  def ordered
    Lexeme.where(kind: :particle).order(Arel.sql("(lexemes.data ->> 'rank')::int NULLS LAST")).to_a
  end

  def word_beyond_particle(entry)
    return nil if entry.data["sole_sense"]

    Lexeme.visible.where(kind: Lexeme::DICTIONARY_KINDS, text: entry.text).order(:kind).first
  end

  def neighbours_of(entry)
    all = ordered
    index = all.index(entry)
    return [nil, nil] if index.nil?

    [(all[index - 1] if index.positive?), all[index + 1]]
  end
end
