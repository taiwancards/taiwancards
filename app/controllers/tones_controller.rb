# frozen_string_literal: true

class TonesController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  publicly_cacheable only: %i[show]
  def show
    current_user&.record_practice_run!(:tones_theory)
  end

  DRILL_SIZE = 24

  def drill
    @items = drill_items
    current_user.record_practice_run!(:tones)
  end

  def refill
    render(json: {items: drill_items})
  end

  private

  def drill_items
    Huayu::ToneDrill.new(user: current_user).items(count: DRILL_SIZE)
  end
end
