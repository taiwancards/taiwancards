# frozen_string_literal: true

module Learn
  class Road
    LEVELS = %w[Novice1 Novice2 A1 A2 B1].freeze

    Milestone = Data.define(:collection_id, :level_tag, :total, :known, :remaining, :state) do
      def readiness
        total.zero? ? 0 : (known * 100.0 / total).round
      end

      def done? = state == :done

      def current? = state == :current
    end

    def initialize(user)
      @user = user
    end

    def milestones
      @milestones ||= build
    end

    def current
      milestones.find(&:current?)
    end

    def plan
      @plan ||= StudyPlan.find_by(user: @user)
    end

    def days_left
      return if plan.nil?

      [(plan.target_date - Date.current).to_i, 0].max
    end

    private

    def build
      stats = Huayu::TocflReadiness
        .new
        .levels
        .select { |stat| LEVELS.include?(stat.collection.level_tag) }
        .sort_by { |stat| LEVELS.index(stat.collection.level_tag) }

      current_seen = false
      stats.map do |stat|
        remaining = [stat.total - stat.known, 0].max
        state = if remaining.zero? && stat.total.positive?
          :done
        elsif current_seen
          :todo
        else
          current_seen = true
          :current
        end

        Milestone.new(
          collection_id: stat.collection.id,
          level_tag: stat.collection.level_tag,
          total: stat.total,
          known: stat.known,
          remaining:,
          state:
        )
      end
    end
  end
end
