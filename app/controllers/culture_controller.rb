# frozen_string_literal: true

class CultureController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable

  def index
    notes = Huayu::CourseLessons.lessons.select(&:culture?).group_by(&:stage)
    @stages = Huayu::CourseLessons.stages.select { |stage| notes.key?(stage.slug) }
    @notes = notes
  end
end
