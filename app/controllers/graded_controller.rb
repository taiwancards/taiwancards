# frozen_string_literal: true

class GradedController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  publicly_cacheable only: %i[index show]

  before_action :set_tier, only: %i[show complete]
  before_action :set_text, only: %i[show complete]

  def index
    @tiers = Graded::Levels.all.select { |tier| Graded::Library.texts(tier.id).any? }
    @shelf = current_user && Graded::Shelf.new(current_user)
  end

  def show
    @texts = Graded::Library.texts(@tier.id)
    @cover = @tier.cover.call(@text.body)
    @readings = Graded::Readings.new.lines(@text)
    @tokens = tokens_for(@text)
    @quiz = Graded::Quiz.new(@text, tokens: @tokens)
    @following = Graded::Library.following(@text)
    @shelf = current_user && Graded::Shelf.new(current_user)
  end

  def complete
    total = Graded::Quiz.new(@text, tokens: tokens_for(@text)).size if params[:score].present?
    GradedCompletion.record(user: current_user, text_id: @text.id, score: params[:score].to_i, total:)
    following = Graded::Library.following(@text)
    target = following ? graded_text_path(tier: following.tier, id: following.id) : graded_path
    redirect_to(target, notice: t("graded.saved"))
  end

  private

  def tokens_for(text)
    Huayu::TextAnalyzer.new(locale: I18n.locale).analyze_map(text.lines.map(&:zh))
  end

  def set_tier
    @tier = Graded::Levels.find(params[:tier])
    redirect_to(graded_path) if @tier.nil? || Graded::Library.texts(@tier.id).empty?
  end

  def set_text
    @text = params[:id].present? ? Graded::Library.find(@tier.id, params[:id]) : Graded::Library.texts(@tier.id).first
    redirect_to(graded_tier_path(tier: @tier.id)) if @text.nil?
  end
end
