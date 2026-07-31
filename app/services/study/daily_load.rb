# frozen_string_literal: true

module Study
  class DailyLoad
    SOFT_MULTIPLE = 2

    def initialize(user = Current.user, now: Time.current, preferences: nil)
      @user = user
      @now = now
      @preferences = preferences || Study::Preferences.for(user)
    end

    def quota
      @quota ||= [@preferences.session_size, 1].max
    end

    def reviews_today
      @reviews_today ||= LexemeReview.where(user: @user, reviewed_at: today).count
    end

    def new_today
      @new_today ||= LexemeReview
        .where(user: @user, reviewed_at: today, state_before: LexemeMemory.states[:unseen])
        .distinct
        .count(:lexeme_id)
    end

    def multiple
      new_today / quota
    end

    def reached? = multiple.positive?

    def overreaching? = multiple >= SOFT_MULTIPLE

    def remaining_in_quota = [quota - (new_today % quota), 0].max

    private

    def today
      @today ||= @now.in_time_zone.beginning_of_day..@now.in_time_zone.end_of_day
    end
  end
end
