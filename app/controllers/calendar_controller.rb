# frozen_string_literal: true

class CalendarController < ApplicationController
  def show
    @first_year = Huayu::LunarCalendar.first_year
    @last_year = Huayu::LunarCalendar.last_year
    @year = requested_year
    @today = Date.current
    @today_lunar = Huayu::LunarCalendar.to_lunar(@today)
    @holidays = Huayu::Holidays.for_year(@year)
    @lunar_year = Huayu::LunarCalendar.years[@year]
    @table = Huayu::LunarCalendar.payload
    @lexemes = holiday_lexemes
    load_memory_state
  end

  private

  def requested_year
    return Date.current.year if @first_year.nil? || @last_year.nil?

    year = params[:year].to_i
    return year if (@first_year..@last_year).cover?(year)

    Date.current.year.clamp(@first_year, @last_year)
  end

  def holiday_lexemes
    Lexeme
      .where(kind: :word, text: Huayu::Holidays.word_texts)
      .visible_to(current_user)
      .index_by(&:text)
  end

  def load_memory_state
    memories = LexemeMemory.owned_by(Current.user).where(lexeme_id: @lexemes.values.map(&:id))
    @started_ids = memories.active.distinct.pluck(:lexeme_id).to_set
    @known_ids = memories.state_review.distinct.pluck(:lexeme_id).to_set
  end
end
