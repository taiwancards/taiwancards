# frozen_string_literal: true

class TimeZonesController < ApplicationController
  def update
    current_user.move_to(params[:zone].to_s) unless impersonating?

    head(:no_content)
  end
end
