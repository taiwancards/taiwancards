# frozen_string_literal: true

class GrammarController < ApplicationController
  allow_unauthenticated_access

  def index
    @levels = Huayu::GrammarLessons.levels
  end

  def show
    @lesson = Huayu::GrammarLessons.find(params[:id])
    raise ActiveRecord::RecordNotFound if @lesson.nil?

    lessons = Huayu::GrammarLessons.all
    position = lessons.index(@lesson)
    @previous = position.positive? ? lessons[position - 1] : nil
    @next = lessons[position + 1]
  end
end
