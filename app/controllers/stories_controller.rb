# frozen_string_literal: true

class StoriesController < ApplicationController
  include ProgressMarks

  before_action :require_restricted_access

  def index
    @category = params[:category].presence_in(Huayu::ReadingStories::CATEGORIES)
    scope = stories.ordered
    scope = scope.where("body_data ->> 'category' = ?", @category) if @category
    @groups = scope.to_a.group_by(&:category)
  end

  def show
    @text = stories.find(params[:id])
    lines = @text.lines
    @lines = lines.zip(analyzer.analyze_lines(lines), @text.translations(I18n.locale))
    @known_ids = known_lexeme_ids(token_lexeme_ids(@lines))
    @neighbors = neighbors
  end

  private

  def stories = ReadingText.where(kind: :story, user_id: nil)

  def analyzer
    @analyzer ||= Huayu::TextAnalyzer.new(locale: I18n.locale)
  end

  def neighbors
    ordered = stories.ordered.pluck(:id)
    index = ordered.index(@text.id)
    {previous: index&.positive? ? ordered[index - 1] : nil, next: index && ordered[index + 1]}
  end
end
