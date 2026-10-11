# frozen_string_literal: true

module Study
  class Upkeep
    SLOW_MS = 7_000
    DISTRACTED_MS = 60_000
    WINDOW_DAYS = 14
    MIN_CHECKS = 10
    LAPSE_SHARE = 0.15
    SLOW_SHARE = 0.25
    EXTRA_PER_DAY = 5
    HORIZON_DAYS = 30
    PREF = "upkeep_on"

    def initialize(user, now: Time.current)
      @user = user
      @now = now
    end

    def rating_for(memory, rating, elapsed_ms)
      return rating unless rating == "good" && slow?(elapsed_ms) && memory.state_review?

      known?(memory.lexeme) ? "hard" : rating
    end

    def refresh
      return if grade < 1 || @user.prefs[PREF] == today.iso8601

      pull_forward if struggling?
      @user.update_columns(prefs: @user.prefs.merge(PREF => today.iso8601))
    end

    def struggling?
      total, lapses, slow = checks.pick(
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(*) FILTER (WHERE lexeme_reviews.rating = 1)"),
        Arel.sql(
          LexemeReview.sanitize_sql_array(
            [
              "COUNT(*) FILTER (WHERE lexeme_reviews.rating > 1 AND lexeme_reviews.elapsed_ms BETWEEN ? AND ?)",
              SLOW_MS,
              DISTRACTED_MS
            ]
          )
        )
      )
      total >= MIN_CHECKS && (lapses >= total * LAPSE_SHARE || slow >= total * SLOW_SHARE)
    end

    private

    def grade = @grade ||= @user.level_grade

    def known?(lexeme) = grade.positive? && lexeme.level_index.present? && lexeme.level_index <= grade

    def slow?(elapsed_ms) = elapsed_ms.to_i.between?(SLOW_MS, DISTRACTED_MS)

    def today = @now.in_time_zone(@user.zone || Time.zone_default).to_date

    def checks
      LexemeReview
        .joins(:lexeme)
        .where(user: @user, reviewed_at: (@now - WINDOW_DAYS.days)..@now)
        .where(state_before: LexemeMemory.states[:review])
        .where(lexemes: {level_index: ..grade})
    end

    def pull_forward
      resting = LexemeMemory
        .owned_by(@user)
        .state_review
        .where(due_at: (@now + HORIZON_DAYS.days)..)
        .joins(:lexeme)
        .where(lexemes: {level_index: ..grade})
      lexeme_ids = resting
        .order(Arel.sql("lexemes.level_index DESC, lexemes.freq_rank DESC NULLS LAST"), :lexeme_id)
        .limit(EXTRA_PER_DAY * 4)
        .pluck(:lexeme_id)
        .uniq
        .first(EXTRA_PER_DAY)
      resting.where(lexeme_id: lexeme_ids).update_all(due_at: @now)
    end
  end
end
