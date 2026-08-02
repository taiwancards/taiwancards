# frozen_string_literal: true

class PhrasesController < ApplicationController
  allow_unauthenticated_access
  ROLES = Huayu::TaiwanPhrases::ROLES

  def index
    @scenes = Huayu::TaiwanPhrases.scenes
    @scene = Huayu::TaiwanPhrases.scene(params[:scene]) || @scenes.first
    @role = params[:role].presence_in(ROLES)
    @patterns = Huayu::TaiwanPhrases.patterns(scene: @scene&.id, role: @role)
    @slots = slots_for(@patterns)
    @lexicon = Phrases::Lexicon.new(@patterns).call
    @counts = Huayu::TaiwanPhrases.counts
    current_user&.record_practice_run!(:phrases)
  end

  private

  def slots_for(patterns)
    patterns
      .flat_map(&:slots)
      .uniq
      .filter_map { |name| Huayu::TaiwanPhrases.slot(name) }
      .select(&:closed?)
  end
end
