# frozen_string_literal: true

module Study
  class TodayDesk
    OVERLOAD = 60

    def initialize(user, now: Time.current)
      @user = user
      @now = now
    end

    def plan
      @plan ||= StudyPlan.find_by(user: @user)
    end

    def summary
      quota = plan ? Study::PlanCalculator.new(plan).daily_new_quota : Setting.instance.session_size.to_i
      total = due_count + quota
      {due: due_count, new: quota, total:, overloaded: total > OVERLOAD, has_plan: plan.present?}
    end

    private

    def facet_ints
      Study::CardSet::SWIPE_FACETS.map { |facet| LexemeMemory.facets[facet] }
    end

    def due_count
      @due_count ||= LexemeMemory
        .active
        .owned_by(@user)
        .joins(:lexeme)
        .where(facet: facet_ints)
        .where
        .not(state: :unseen)
        .where(due_at: ..@now)
        .distinct
        .count(:lexeme_id)
    end
  end
end
