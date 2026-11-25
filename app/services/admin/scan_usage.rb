# frozen_string_literal: true

module Admin
  class ScanUsage
    WINDOWS = [7, 30, 90].freeze
    DAY = "DATE(scans.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Taipei')"

    Day = Data.define(:day, :scans, :failed, :refunded, :input_tokens, :output_tokens, :cost)

    def initialize(days:, now: Time.current)
      @now = now.in_time_zone(Time.zone_default)
      @since = (@now.to_date - (days - 1)).beginning_of_day
    end

    def days = @days ||= load_days

    def totals
      list = days
      Day.new(
        day: nil,
        scans: list.sum(&:scans),
        failed: list.sum(&:failed),
        refunded: list.sum(&:refunded),
        input_tokens: list.sum(&:input_tokens),
        output_tokens: list.sum(&:output_tokens),
        cost: list.sum { |row| row.cost.to_f }
      )
    end

    def failures = scope.failed.group(:failure).order(Arel.sql("COUNT(*) DESC")).count

    def models = scope.group(:model).count

    def learners = scope.distinct.count(:user_id)

    def today = Scan.where(created_at: @now.all_day).count

    def in_flight = Scan.in_flight.count

    def at_quota
      Scan
        .where(day: @now.to_date - 1..@now.to_date + 1)
        .counted
        .group(:user_id, :day)
        .having("COUNT(*) >= ?", Scan::DAILY)
        .count
        .size
    end

    def pauses = ScanPause.recent.limit(10)

    def pause = ScanPause.current

    def average_latency = scope.done.average(:latency_ms)&.round

    private

    def scope = Scan.where(created_at: @since..)

    def load_days
      rows = scope
        .group(Arel.sql(DAY), :model)
        .pluck(
          Arel.sql(DAY),
          :model,
          Arel.sql("COUNT(*)"),
          Arel.sql("COUNT(*) FILTER (WHERE failure IS NOT NULL)"),
          Arel.sql("COUNT(*) FILTER (WHERE NOT counted)"),
          Arel.sql("COALESCE(SUM(input_tokens), 0)"),
          Arel.sql("COALESCE(SUM(output_tokens), 0)")
        )
      rows.group_by(&:first).sort.reverse.map { |day, models| summarize(day, models) }
    end

    def summarize(day, models)
      Day.new(
        day:,
        scans: models.sum { |row| row[2] },
        failed: models.sum { |row| row[3] },
        refunded: models.sum { |row| row[4] },
        input_tokens: models.sum { |row| row[5] },
        output_tokens: models.sum { |row| row[6] },
        cost: models.sum { |row| Scans::Pricing.cost(row[1], row[5], row[6]).to_f }
      )
    end
  end
end
