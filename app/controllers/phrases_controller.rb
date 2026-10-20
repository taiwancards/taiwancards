# frozen_string_literal: true

class PhrasesController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  ROLES = Huayu::TaiwanPhrases::ROLES

  def index
    @scenes = Huayu::TaiwanPhrases.scenes
    @scene = Huayu::TaiwanPhrases.scene(params[:scene]) || @scenes.first
    @role = params[:role].presence_in(ROLES)
    @patterns = Huayu::TaiwanPhrases.patterns(scene: @scene&.id, role: @role)
    @slots = slots_for(@patterns)
    @lexicon = Phrases::Lexicon.new(@patterns, user: current_user).call
    @counts = Huayu::TaiwanPhrases.counts
    @dialogue = Huayu::TaiwanPhrases.dialogue(@scene&.id)
    current_user&.record_practice_run!(:phrases)
  end

  def dialogue
    @scene = Huayu::TaiwanPhrases.scene(params[:scene])
    @dialogue = Huayu::TaiwanPhrases.dialogue(params[:scene])
    return redirect_to(phrases_path) if @scene.nil? || @dialogue.nil?

    @readings = Huayu::SentenceReadings.new(analyzer: Huayu::TextAnalyzer.new).call(@dialogue.chinese)
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
