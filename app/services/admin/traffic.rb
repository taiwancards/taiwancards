# frozen_string_literal: true

module Admin
  class Traffic
    WINDOWS = [7, 30, 90].freeze
    TOP = 20
    SECTION = "CASE WHEN path LIKE 'site:%' THEN 'site' ELSE COALESCE(NULLIF(SPLIT_PART(path, '/', 2), ''), 'home') END"

    def initialize(days:, today: Date.current)
      @range = (today - (days - 1))..today
    end

    def total = @total ||= scope.sum(:views)

    def by_day = scope.group(:day).order(:day).sum(:views)

    def sections = top(Arel.sql(SECTION))

    def paths = top(:path)

    def sources = top(:source)

    def devices = top(:device)

    def countries = top(:country)

    def locales = top(:locale)

    def signups
      User
        .where(admin: false, created_at: @range.begin.beginning_of_day..)
        .group(Arel.sql("COALESCE(prefs->>'signup_from', '')"))
        .count
    end

    private

    def scope = PageView.where(day: @range)

    def top(column) = scope.group(column).order(Arel.sql("SUM(views) DESC")).limit(TOP).sum(:views)
  end
end
