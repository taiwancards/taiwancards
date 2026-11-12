# frozen_string_literal: true

class ReaderController < ApplicationController
  include ProgressMarks

  before_action :set_text, only: %i[show create_desk]

  rate_limit(
    to: 20,
    within: 5.minutes,
    only: :create,
    with: -> { redirect_to(new_reader_text_path, alert: t("desks.too_fast")) }
  )

  def index
    @kind = params[:kind].presence_in(ReadingText::LIBRARY_KINDS)
    scope = ReadingText.visible_to(current_user).library.recent
    scope = scope.where(kind: @kind) if @kind
    @texts = scope.limit(100).to_a
  end

  def new
    @text = ReadingText.new(kind: :article)
  end

  def create
    body, changed = Huayu::SimpToTrad.convert(params.dig(:reading_text, :body).to_s)
    return redirect_to(new_reader_text_path, alert: t("reader.empty_body")) if body.blank?
    return redirect_to(new_reader_text_path, alert: too_long_message) if body.length > ReadingText::LEARNER_LIMIT

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
    lexeme = Lexeme.visible_to(current_user).find_by(id: numeric_id(params[:lexeme_id]))
    raise ActiveRecord::RecordNotFound if lexeme.nil?

    Lexemes::Activator.new(user: current_user).call(lexeme)
    head(:no_content)
  end

  def show
    lines = @text.lines
    @lines = lines.zip(analyzer.analyze_lines(lines))
    @known_ids = known_lexeme_ids(token_lexeme_ids(@lines))
  end

  def destroy
    ReadingText.removable_by(current_user).find(params[:id]).destroy!
    redirect_to(reader_path, notice: t("reader.deleted"))
  end

  def create_desk
    own = @text.user_id == current_user.id
    return redirect_to(reader_text_path(@text)) if own && @text.collection.present?

    desk = Collections::DeskBuilder.new(user: current_user).call(text: @text.body, name: @text.title)
    @text.update!(collection: desk) if own
    redirect_to(my_desk_path(desk), notice: t("desks.created"))
  end

  private

  def set_text
    @text = ReadingText.visible_to(current_user).find(params[:id])
  end

  def analyzer
    @analyzer ||= Huayu::TextAnalyzer.new(locale: I18n.locale)
  end

  def too_long_message
    t(
      "errors.format",
      attribute: t("reader.body_label"),
      message: t("errors.messages.too_long", count: ReadingText::LEARNER_LIMIT)
    )
  end
end
