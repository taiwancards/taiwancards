# frozen_string_literal: true

class PhraseDrillsController < ApplicationController
  before_action :require_restricted_access

  LEVELS = %w[1 2 3 4 5].freeze
  LEVEL_SPAN = Lexemes::Difficulty::SCALE / 5
  PER_PAGE = 25

  def index
    @level = params[:level].presence_in(LEVELS)
    @scheme = params[:scheme].presence_in(SentenceProfile::SCHEMES.keys - ["freq"])
    @grade = params[:grade].presence_in(grades_for(@scheme))
    @q = params[:q].to_s.strip

    scope = filtered
    @total = scope.count
    @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @pages)

    @phrases = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @tokens = Huayu::TextAnalyzer.new(locale: I18n.locale).analyze_lines(@phrases.map(&:text))
  end

  private

  def filtered
    scope = Huayu::PhraseDrillsImporter.drills
    scope = scope.where("(lexemes.data ->> 'difficulty')::int BETWEEN ? AND ?", *band(@level)) if @level
    scope = scope.where("(lexemes.data ->> ?)::int = ?", @scheme, @grade.to_i) if @scheme && @grade
    return scope if @q.blank?

    scope.where(
      "lexemes.text ILIKE :q OR lexemes.meanings ->> 'en' ILIKE :q OR lexemes.meanings ->> 'ru' ILIKE :q",
      q: "%#{@q}%"
    )
  end

  def grades_for(scheme)
    return [] if scheme.nil?

    (1..SentenceProfile::SCHEMES.fetch(scheme)[:levels].length).map(&:to_s)
  end

  def band(level)
    lower = (level.to_i - 1) * LEVEL_SPAN
    upper = level == LEVELS.last ? Lexemes::Difficulty::SCALE : lower + LEVEL_SPAN - 1
    [lower, upper]
  end
end
