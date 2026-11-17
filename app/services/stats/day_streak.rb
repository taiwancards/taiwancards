# frozen_string_literal: true

module Stats
  class DayStreak
    REST_TIERS = {90 => 4, 30 => 2}.freeze

    Ahead = Data.define(:days, :rest)

    Streak = Data.define(:current, :since, :longest, :days, :state, :rests, :allowance, :ahead) do
      def done? = state == :done

      def rest_on?(date) = rests.include?(date)
    end

    Run = Data.define(:since, :last, :studied, :clean, :rests) do
      def self.start(day) = new(since: day, last: day, studied: 1, clean: 1, rests: [])

      def missed_before(day) = (day - last).to_i - 1

      def extend_to(day)
        missed = missed_before(day)
        with(
          last: day,
          studied: studied + 1,
          clean: missed.zero? ? clean + 1 : 1,
          rests: rests + ((last + 1)...day).to_a
        )
      end
    end

    def self.allowance(clean) = REST_TIERS.find { |threshold, _| clean >= threshold }&.last.to_i

    def self.ahead(clean)
      threshold, rest = REST_TIERS.select { |tier, _| tier > clean }.min_by(&:first)
      threshold && Ahead.new(days: threshold - clean, rest:)
    end

    def initialize(days, today:)
      @days = days
      @today = today
    end

    def call
      runs = walk
      run = runs.last
      state = state_of(run)
      return none(runs) if state == :none

      missed = [run.missed_before(@today), 0].max
      Streak.new(
        current: run.studied,
        since: run.since,
        longest: longest(runs),
        days: @days.length,
        state:,
        rests: run.rests + ((run.last + 1)...@today).to_a,
        allowance: self.class.allowance(run.clean) - missed,
        ahead: state == :resting ? nil : self.class.ahead(run.clean)
      )
    end

    private

    def walk
      @days.each_with_object([]) do |day, runs|
        run = runs.last
        if run && run.missed_before(day) <= self.class.allowance(run.clean)
          runs[-1] = run.extend_to(day)
        else
          runs << Run.start(day)
        end
      end
    end

    def state_of(run)
      return :none unless run
      return :done if run.last >= @today

      missed = run.missed_before(@today)
      return :pending if missed.zero?
      return :resting if missed <= self.class.allowance(run.clean)

      :none
    end

    def longest(runs) = runs.map(&:studied).max.to_i

    def none(runs)
      Streak.new(
        current: 0,
        since: nil,
        longest: longest(runs),
        days: @days.length,
        state: :none,
        rests: [],
        allowance: 0,
        ahead: nil
      )
    end
  end
end
