# frozen_string_literal: true

class StarterLessonsController < ApplicationController
  OPTIONS = 4
  POOL = 12
  REFRESH = 3

  before_action :set_lesson

  def show
    @entries = entries
    @pool = Huayu::StarterTrack.words_before(@lesson).last(POOL)
    @symbols = Huayu::StarterTrack.symbols_through(@lesson)
    @quiz = @lesson.symbols.presence || weakest_symbols
  end

  def complete
    lexemes = starter.complete!(@lesson, symbols: symbol_results, words: word_results)
    session[:starter_learned] = lexemes.map(&:id)
    redirect_to(starter_lesson_done_path(@lesson))
  end

  def done
    ids = Array(session.delete(:starter_learned)).map(&:to_i)
    @learned = Lexeme.where(id: ids).index_by(&:id).values_at(*ids).compact
    @starter = starter
    @next = @starter.next_lesson
  end

  private

  def set_lesson
    @lesson = Huayu::StarterTrack.find(params[:slug])
    raise ActiveRecord::RecordNotFound if @lesson.nil?
  end

  def starter = @starter ||= Learn::Starter.new(current_user)

  def weakest_symbols
    mastery = current_user.zhuyin_mastery.to_h
    @symbols.min_by(REFRESH) { |symbol|
      entry = mastery[symbol].to_h
      [entry["streak"].to_i, entry["correct"].to_f / [entry["seen"].to_i, 1].max]
    }
  end

  def entries
    @entries ||= begin
      found = Lexeme
        .where(kind: %i[word character], text: @lesson.words.map(&:zh))
        .sort_by { |lexeme| lexeme.word? ? 0 : 1 }
        .uniq(&:text)
        .index_by(&:text)
      @lesson.words.filter_map { |word| found[word.zh] && [word, found[word.zh]] }
    end
  end

  def results(key)
    parsed = JSON.parse(params[key].to_s)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  def symbol_results = results(:symbols).to_h { |symbol, correct| [symbol.to_s, correct == true] }

  def word_results
    allowed = entries.to_set { |_word, lexeme| lexeme.id }
    results(:words).filter_map { |id, correct| [id.to_i, correct == true] if allowed.include?(id.to_i) }.to_h
  end
end
