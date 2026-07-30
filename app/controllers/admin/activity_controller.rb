# frozen_string_literal: true

module Admin
  class ActivityController < ApplicationController
    before_action :require_admin

    RECENT_LIMIT = 150
    WINDOW = 7.days

    def index
      @since = WINDOW.ago
      @events = ActivityEvent.recent.includes(:user).limit(RECENT_LIMIT).to_a

      recent = ActivityEvent.since(@since)
      @per_user = recent.joins(:user).group("users.email").order(Arel.sql("count(*) DESC")).count
      @per_section = recent.group(:controller).order(Arel.sql("count(*) DESC")).limit(15).count
      @per_day = recent.group(Arel.sql("date(created_at)")).order(Arel.sql("date(created_at)")).count
      @total = ActivityEvent.count
    end
  end
end
