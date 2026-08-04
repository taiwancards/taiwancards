# frozen_string_literal: true

class NumbersController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  SIZE = 12

  def show
    @stages = Huayu::NumberDrill::STAGES
    @stage = params[:stage].to_s.presence_in(@stages) || @stages.first
    @items = Huayu::NumberDrill.new.items(@stage, count: SIZE)
    @size = SIZE
  end

  def result
    current_user&.record_practice_run!(:numbers)
    head(:no_content)
  end
end
