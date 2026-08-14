# frozen_string_literal: true

class StoriesController < ApplicationController
  before_action :require_restricted_access

  def index
    @category = params[:category].presence_in(Huayu::ReadingStories::CATEGORIES)
    scope = ReadingText.where(kind: :story).ordered
    scope = scope.where("body_data ->> 'category' = ?", @category) if @category
    @groups = scope.to_a.group_by(&:category)
  end

  def show
    @text = ReadingText.where(kind: :story).find(params[:id])
    lines = @text.lines
    @lines = lines.zip(analyzer.analyze_lines(lines), @text.translations(I18n.locale))
    @known_ids = known_lexeme_ids(@lines)
    @neighbours = neighbours
  end

  private

  def analyzer
    @analyzer ||= Huayu::TextAnalyzer.new(locale: I18n.locale)
  end

  def neighbours
    ordered = ReadingText.where(kind: :story).ordered.pluck(:id)
    index = ordered.index(@text.id)
    {previous: index&.positive? ? ordered[index - 1] : nil, next: index && ordered[index + 1]}
  end

  def known_lexeme_ids(lines)
    ids = lines.flat_map { |_line, tokens, _translation| tokens.filter_map { |token| token.lexeme&.id } }.uniq
    return Set.new if ids.empty?

    LexemeMemory
      .owned_by(current_user)
      .active
      .where(lexeme_id: ids)
      .where
      .not(state: :unseen)
      .distinct
      .pluck(:lexeme_id)
      .to_set
  end
end
