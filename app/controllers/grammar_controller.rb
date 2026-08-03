# frozen_string_literal: true

class GrammarController < ApplicationController
  allow_unauthenticated_access

  def index
    @levels = Huayu::GrammarLessons.levels
    @level = params[:level].to_i if @levels.key?(params[:level].to_i)
    @shown = @level ? @levels.slice(@level) : @levels
  end

  def show
    @lesson = Huayu::GrammarLessons.find(params[:id])
    raise ActiveRecord::RecordNotFound if @lesson.nil?

    @entries = helpers.grammar_entries_for([@lesson])
    lessons = Huayu::GrammarLessons.taught
    position = lessons.index(@lesson)
    @previous = position && position.positive? ? lessons[position - 1] : nil
    @next = position ? lessons[position + 1] : nil
  end
end
