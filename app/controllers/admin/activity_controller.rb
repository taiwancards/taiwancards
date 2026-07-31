# frozen_string_literal: true

module Admin
  class ActivityController < ApplicationController
    include Paginated

    before_action :require_admin

    PER_PAGE = 60
    WINDOWS = [1, 7, 30].freeze

    def index
      @days = params[:days].to_i.presence_in(WINDOWS) || WINDOWS.first
      @user = User.find_by(id: numeric_id(params[:user_id]))
      @digest = Admin::ActivityDigest.new(days: @days, user: @user)

      events, = paginate(@digest.events, per_page: PER_PAGE, total: @digest.total)
      @events = events.to_a
    end
  end
end
