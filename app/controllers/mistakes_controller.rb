# frozen_string_literal: true

class MistakesController < ApplicationController
  HEATMAP_DAYS = 84
  LEECH_LIMIT = 30

  def show
    @book = Study::MistakeBook.new(current_user)
    @report = StatsReport.new(user: current_user)
    @by_day = @report.reviews_by_day(days: HEATMAP_DAYS)
    @streak = @report.streak
    @retention = @report.actual_retention
    @leeches = @report.leeches.limit(LEECH_LIMIT)
  end
end
