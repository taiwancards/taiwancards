# frozen_string_literal: true

class GradedController < ApplicationController
  allow_unauthenticated_access

  def index
    @tiers = Graded::Levels.all.select { |tier| Graded::Library.texts(tier.id).any? }
  end

  def show
    @tier = Graded::Levels.find(params[:tier])
    return redirect_to(graded_path) if @tier.nil?

    @texts = Graded::Library.texts(@tier.id)
    return redirect_to(graded_path) if @texts.empty?

    @text = params[:id].present? ? Graded::Library.find(@tier.id, params[:id]) : @texts.first
    return redirect_to(graded_tier_path(tier: @tier.id)) if @text.nil?

    @cover = @tier.cover.call(@text.body)
    @readings = Graded::Readings.new.lines(@text)
    @tokens = Huayu::TextAnalyzer.new(locale: I18n.locale).analyze_map(@text.lines.map(&:zh))
  end
end
