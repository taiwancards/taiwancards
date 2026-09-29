# frozen_string_literal: true

class ProgressController < ApplicationController
  RANGES = %w[today yesterday week month all].freeze
  LEECH_LIMIT = 12

  def show
    @report = StatsReport.new(user: current_user)
    @settings = Setting.instance
    @tocfl = Huayu::TocflReadiness.new(user: current_user).levels
    @tbcl = Huayu::TbclReadiness.new(user: current_user).levels
    @leeches = @report.leeches.limit(LEECH_LIMIT).to_a
  end

  def history
    @range = params[:range].presence_in(RANGES) || "today"
    history = Stats::History.new(user: current_user)
    @buckets = history.buckets
    @summary = history.summary(@range)
    @entries = history.entries(@range)
    @overview = history.overview
  end

  def data
    @summary = Progress::Summary.new(current_user)
    @memory_count = current_user.lexeme_memories.count
    @review_count = current_user.lexeme_reviews.count
  end
end
