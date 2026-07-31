# frozen_string_literal: true

module Admin
  class UserProfile
    WINDOW_DAYS = 30
    WINDOW = WINDOW_DAYS.days
    TOP_SECTIONS = 12

    def initialize(user, now: Time.current)
      @user = user
      @now = now
    end

    def since = now - WINDOW

    def counts
      @counts ||= {
        decks: user.collections.where(kind: :manual).count,
        cards: user.lexeme_memories.active.count,
        reviews: user.lexeme_reviews.count,
        recent_reviews: user.lexeme_reviews.where(reviewed_at: since..).count,
        pronunciation: user.pronunciation_attempts.count,
        texts: user.reading_texts.count,
        events: user.activity_events.count
      }
    end

    def last_review_at = @last_review_at ||= user.lexeme_reviews.maximum(:reviewed_at)

    def facets
      @facets ||= user.lexeme_reviews.where(reviewed_at: since..).group(:facet).count.sort_by { |_facet, n| -n }
    end

    def sections
      @sections ||= user
        .activity_events
        .where(created_at: since..)
        .group(:controller)
        .order(Arel.sql("count(*) DESC"))
        .limit(TOP_SECTIONS)
        .count
    end

    def plan = @plan ||= user.study_plans.first

    def placement = @placement ||= user.placement_tests.order(created_at: :desc).first

    private

    attr_reader :user, :now
  end
end
