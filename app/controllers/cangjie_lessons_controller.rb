# frozen_string_literal: true

class CangjieLessonsController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable

  def index
    @stages = Huayu::CangjieLessons.stages
    @by_stage = Huayu::CangjieLessons.by_stage
    @groups = Huayu::CangjieLessons.groups
  end

  def show
    @lesson = Huayu::CangjieLessons.find(params[:id])
    raise ActiveRecord::RecordNotFound if @lesson.nil?

    @previous, @next = Huayu::CangjieLessons.neighbours(@lesson)
  end
end
