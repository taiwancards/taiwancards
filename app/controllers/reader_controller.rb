# frozen_string_literal: true

class ReaderController < ApplicationController
  before_action :set_language
  before_action :set_text, only: %i[show destroy create_desk]

  def index
    @kind = params[:kind].presence_in(ReadingText.kinds.keys)
    scope = ReadingText.visible_to(current_user).recent
    scope = scope.where(kind: @kind) if @kind
    @texts = scope.limit(100).to_a
  end

  def new
    @text = ReadingText.new(kind: :article)
  end

  def create
    body, changed = Huayu::SimpToTrad.convert(params.dig(:reading_text, :body).to_s)
    return redirect_to(new_reader_text_path, alert: t("reader.empty_body")) if body.blank?

    text = ReadingText.create!(
      user: current_user,
      kind: params.dig(:reading_text, :kind).presence_in(%w[article graded]) || "article",
      title: params.dig(:reading_text, :title).presence || t("reader.untitled"),
      level_tag: params.dig(:reading_text, :level_tag).presence,
      source: "manual",
      body:,
      body_data: {"changed_chars" => changed}
    )
    redirect_to(reader_text_path(text), notice: t("reader.created"))
  end

  def activate
    lexeme = Lexeme.find_by(id: numeric_id(params[:lexeme_id]))
    raise ActiveRecord::RecordNotFound if lexeme.nil?

    Lexemes::Activator.new.call(lexeme)
    head(:no_content)
  end

  def show
    @lines = @text.lines.map { |line| [line, analyzer.analyze(line)] }
    @known_ids = known_lexeme_ids(@lines)
  end

  def destroy
    @text.destroy!
    redirect_to(reader_path, notice: t("reader.deleted"))
  end

  def create_desk
    return redirect_to(reader_text_path(@text)) if @text.collection.present?

    desk = Collections::DeskBuilder.new(user: current_user).call(text: @text.body, name: @text.title)
    @text.update!(collection: desk)
    redirect_to(my_desk_path(desk), notice: t("desks.created"))
  end

  private

  def set_language
  end

  def set_text
    @text = ReadingText.visible_to(current_user).find(params[:id])
  end

  def analyzer
    @analyzer ||= Huayu::TextAnalyzer.new(locale: I18n.locale)
  end

  def known_lexeme_ids(lines)
    ids = lines.flat_map { |_line, tokens| tokens.filter_map { |token| token.lexeme&.id } }.uniq
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
