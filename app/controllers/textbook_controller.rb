# frozen_string_literal: true

class TextbookController < ApplicationController
  before_action :require_restricted_access

  def index
    @books = TextbookLesson.books
  end

  def show
    @textbook_lesson = TextbookLesson.find_by!(book: params[:book], lesson: params[:lesson])
    @neighbors = neighbors(@textbook_lesson)
    @collection = Collection
      .all
      .where("name LIKE ?", "Textbook #{@textbook_lesson.label} ·%")
      .first
  end

  def mark_known
    textbook_lesson = TextbookLesson.find_by!(book: params[:book], lesson: params[:lesson])
    texts = textbook_lesson.words.flat_map do |entry|
      Textbook::Spellings.of(entry["traditional"].presence || entry["word"])
    end

    lexemes = Lexeme
      .where(kind: %i[character word])
      .where(text: texts.uniq)
      .to_a

    result = Lexemes::KnownMarker.new(current_user).call(lexemes)

    redirect_to(
      textbook_lesson_path(book: params[:book], lesson: params[:lesson]),
      notice: t("textbook.marked_known", count: result[:lexemes])
    )
  end

  private

  def neighbors(current)
    ordered = TextbookLesson.ordered.pluck(:book, :lesson)
    index = ordered.index([current.book, current.lesson])
    {
      previous: index&.positive? ? ordered[index - 1] : nil,
      next: index && ordered[index + 1]
    }
  end
end
