# frozen_string_literal: true

class CalendarController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable ttl: 1.hour, stale: 1.hour
  include ProgressMarks

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
    load_progress(@lexemes.values)
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
      .where(kind: Lexeme::DICTIONARY_KINDS, text: Huayu::Holidays.word_texts)
      .visible_to(current_user)
      .index_by(&:text)
  end
end
